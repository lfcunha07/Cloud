terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = "us-east-1"
}

# Declare the data source
data "aws_availability_zones" "available" {
  state = "available"
}

# Create VPC module
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "luis-vpc"
  cidr = "192.168.0.0/25"

  azs             = data.aws_availability_zones.available.names
  public_subnets  = ["192.168.0.0/26", "192.168.0.64/26"]
  #private_subnets = ["192.168.0.127/27", "192.168.0.191/27"]

  enable_nat_gateway = true
  enable_vpn_gateway = true

  map_public_ip_on_launch = true

  tags = {
    Terraform = "true"
    Environment = "dev"
  }
}

# Create EKS module
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 18.21.0"

  cluster_name    = "luis-cluster"
  cluster_version = "1.22"

  cluster_endpoint_private_access = true
  cluster_endpoint_public_access  = true

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.public_subnets

  # EKS Managed Node Group(s)
  eks_managed_node_group_defaults = {
    disk_size      = 50
    instance_types = ["t2.medium"]

    tags = {
      "kubernets.io/cluster/luis-cluster" = "owned"
    }
  }

  eks_managed_node_groups = {
    luis-node-group = {
      min_size     = 3
      max_size     = 3
      desired_size = 3

      instance_types = ["t2.medium"]
      capacity_type  = "SPOT"
    }
  }

  # aws-auth configmap
  # manage_aws_auth_configmap = true

  tags = {
    Environment = "dev"
    Terraform   = "true"
  }
}