resource "aws_eip" "nat" {
  count = 1

  domain = "vpc"
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "4.0.2"

  name        = "${local.name}-vpc"
  cidr        = local.vpc_cidr
  enable_ipv6 = false

  azs             = local.azs
  private_subnets = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 4, k)]
  public_subnets  = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k + 48)]

  private_subnet_names = [for k, v in local.azs : "${local.name}-subnet-private${k + 1}-${v}"]
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" : "1"
  }
  public_subnet_names = [for k, v in local.azs : "${local.name}-subnet-public${k + 1}-${v}"]
  public_subnet_tags = {
    "kubernetes.io/role/elb" : "1"
  }

  manage_default_network_acl    = true
  manage_default_route_table    = true
  manage_default_security_group = true

  create_igw = true
  igw_tags = {
    Name = "${local.name}-igw"
  }

  reuse_nat_ips       = true
  external_nat_ip_ids = aws_eip.nat.*.id

  enable_nat_gateway     = true
  single_nat_gateway     = true
  one_nat_gateway_per_az = false
  nat_gateway_tags = {
    Name = format(
      "${local.name}-nat-public1-%s",
      element(local.azs, 0),
    )
  }

  enable_vpn_gateway = false

  enable_dns_hostnames = true
  enable_dns_support   = true
}
