module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "19.15.1"

  cluster_name    = local.name
  cluster_version = "1.26"

  create_iam_role = false
  iam_role_arn    = local.eks_cluster_iam_role_arn

  create_kms_key            = false
  cluster_encryption_config = {}

  vpc_id                     = module.vpc.vpc_id
  subnet_ids                 = module.vpc.private_subnets
  create_cni_ipv6_iam_policy = false

  create_cluster_security_group              = true
  create_cluster_primary_security_group_tags = true
  # Extend cluster security group rules
  cluster_security_group_additional_rules = {
    ingress_nodes_ephemeral_ports_tcp = {
      description                = "Nodes on ephemeral ports"
      protocol                   = "tcp"
      from_port                  = 1025
      to_port                    = 65535
      type                       = "ingress"
      source_node_security_group = true
    }
    # Test: https://github.com/terraform-aws-modules/terraform-aws-eks/pull/2319
    ingress_source_security_group_id = {
      description              = "Ingress from another computed security group"
      protocol                 = "tcp"
      from_port                = 22
      to_port                  = 22
      type                     = "ingress"
      source_security_group_id = aws_security_group.eks_additional.id
    }
  }

  create_node_security_group = true
  # Extend node-to-node security group rules
  node_security_group_additional_rules = {
    ingress_self_all = {
      description = "Node to node all ports/protocols"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      type        = "ingress"
      self        = true
    }
    # Test: https://github.com/terraform-aws-modules/terraform-aws-eks/pull/2319
    ingress_source_security_group_id = {
      description              = "Ingress from another computed security group"
      protocol                 = "tcp"
      from_port                = 22
      to_port                  = 22
      type                     = "ingress"
      source_security_group_id = aws_security_group.eks_additional.id
    }
  }

  cluster_endpoint_public_access       = true
  cluster_endpoint_public_access_cidrs = ["0.0.0.0/0"]
  cluster_endpoint_private_access      = true

  create_cloudwatch_log_group = false
  cluster_enabled_log_types   = []

  cluster_addons = {
    coredns = {
      most_recent = true

      timeouts = {
        create = "25m"
        delete = "10m"
      }
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }
  }

  # Self Managed Node Group(s)
  self_managed_node_group_defaults = {}
  self_managed_node_groups         = {}

  # EKS Managed Node Group(s)
  eks_managed_node_group_defaults = {
    ami_type       = "AL2_x86_64"
    instance_types = ["t3.large"]
    disk_size      = 20

    attach_cluster_primary_security_group = true
    vpc_security_group_ids                = [aws_security_group.eks_additional.id]
    create_iam_role                       = false
    iam_role_arn                          = local.eks_managed_node_group_iam_role_arn
    create_launch_template                = true
  }

  eks_managed_node_groups = {
    large = {
      min_size     = 1
      max_size     = 4
      desired_size = 1

      instance_types = ["t3.large"]
      capacity_type  = "SPOT"
      labels = {
        color = "large"
      }

      taints = {}

      update_config = {
        max_unavailable = 1
      }

      tags = merge(
        data.aws_default_tags.current.tags,
        {
          Name = "${local.name}-eks-managed-node-group-large"
        }
      )
    }
  }

  # Fargate Profile(s)
  fargate_profile_defaults = {
    create_iam_role = false
    iam_role_arn    = local.eks_fargate_profile_iam_role_arn
  }
  fargate_profiles = {
    default = {
      name = "default"
      selectors = [
        {
          namespace = "kube-system"
          labels = {
            k8s-app = "kube-dns"
          }
        },
        {
          namespace = "default"
        }
      ]

      tags = {
        Name = "${local.name}-fargate-profile-default"
      }

      timeouts = {
        create = "20m"
        delete = "20m"
      }
    }

    game-2048 = {
      name = "game-2048"
      selectors = [
        {
          namespace = "game-2048"
        }
      ]

      tags = {
        Name = "${local.name}-fargate-profile-game-2048"
      }

      timeouts = {
        create = "20m"
        delete = "20m"
      }
    }
  }

  # aws-auth configmap
  create_aws_auth_configmap = false
  manage_aws_auth_configmap = false

  tags = {
    Name = "${local.name}"
  }
}

resource "aws_security_group" "eks_additional" {
  name   = "${local.name}-eks_additional-sg"
  vpc_id = module.vpc.vpc_id

  ingress {
    from_port = 22
    to_port   = 22
    protocol  = "tcp"
    cidr_blocks = [
      module.vpc.vpc_cidr_block
    ]
  }

  tags = {
    Name = "${local.name}-eks_additional-sg"
  }
}
