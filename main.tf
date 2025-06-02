# Variables
variable "aws_region" {
  default = "us-east-1"
}

variable "cluster_name" {
  default = "eks-cluster"
}

variable "private_subnets" {
  default = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "public_subnets" {
  default = ["10.0.101.0/24", "10.0.102.0/24"]
}

variable "enable_nat_gateway" {
  type = bool
  default =  true
}

variable "single_nat_gateway" {
    type = bool
    default = true
  
}

variable "vpc_name" {
  default = "eks-vpc"
}

variable "vpc_cidr" {
  default = "10.0.0.0/16"
}

variable "eks_access" {
  default = "eks_access"
}

variable "cluster_endpoint_public_access" {
  type = bool
  default = true
}

variable "aws_ecr_repository_name" {
  default = "microservice-repo"
}

variable "image_tag_mutability" {
  default = "MUTABLE"
}

variable "Environment" {
  default = "dev"
}

variable "github_repo" {
  description = "GitHub repo in the format owner"
  type        = string
  default = "sahanineha/usercase1"
}

variable "github_oidc_role_name" {
  default = "github-oidc-role"
}

variable "github_oidc_policy_name" {
  default = "github-oidc-policy"
}
#################################################

provider "aws" {
  region = var.aws_region
}

##################################################


resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = [
    "sts.amazonaws.com"
  ]

  thumbprint_list = [
    "6EA3857F2B0931B28CEBDD4E865F6130219F66AA"
  ] # GitHub's known root CA fingerprint
}

data "aws_iam_policy_document" "github_oidc_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [
           aws_iam_openid_connect_provider.github.arn
 /*       "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/token.actions.githubusercontent.com" */
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = [
        "repo:${var.github_repo}:ref:refs/heads/main"
      ]
    }
  }
}

resource "aws_iam_role" "github_oidc" {
  name               = var.github_oidc_role_name
  assume_role_policy = data.aws_iam_policy_document.github_oidc_assume_role.json

tags = {
    Environment = var.Environment
  }
}

resource "aws_iam_role_policy" "github_oidc_policy" {
  name = var.github_oidc_policy_name
  role = aws_iam_role.github_oidc.name

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "eks:DescribeCluster",
          "eks:ListClusters",
          "eks:UpdateClusterConfig",
          "eks:AccessKubernetesApi"
        ],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:CompleteLayerUpload",
          "ecr:GetDownloadUrlForLayer",
          "ecr:InitiateLayerUpload",
          "ecr:PutImage",
          "ecr:UploadLayerPart"
        ],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = [
          "sts:AssumeRole",
          "iam:PassRole"
        ],
        Resource = "*"
      }
    ]
  })
  
  
}

##################################################

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.21.0"

  name = var.vpc_name
  cidr = var.vpc_cidr

  azs             = ["${var.aws_region}a", "${var.aws_region}b"]
  private_subnets = var.private_subnets
  public_subnets  = var.public_subnets

  enable_nat_gateway = var.enable_nat_gateway
  single_nat_gateway = var.single_nat_gateway

  tags = {
    Environment = var.Environment
  }
}
##################################################

 resource "aws_iam_role" "eks_access" {
  name = var.eks_access

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Environment = var.Environment
  }
}
##################################################
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = var.cluster_name
  cluster_version = "1.31"

  cluster_endpoint_public_access  = var.cluster_endpoint_public_access

  cluster_addons = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }
  }

  vpc_id                   = module.vpc.vpc_id
  subnet_ids               = module.vpc.private_subnets
  control_plane_subnet_ids = module.vpc.public_subnets

  # EKS Managed Node Group(s)
  eks_managed_node_group_defaults = {
    instance_types = ["t3.medium"]
  }

  eks_managed_node_groups = {
    example = {
      min_size     = 1
      max_size     = 2
      desired_size = 1

      instance_types = ["t3.medium"]
      capacity_type  = "SPOT"
    }
  }

  # Cluster access entry
  # To add the current caller identity as an administrator
  enable_cluster_creator_admin_permissions = true

  access_entries = {
    # One access entry with a policy associated
    example = {
      kubernetes_groups = []
      principal_arn     = aws_iam_role.eks_access.arn

      policy_associations = {
        example = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSViewPolicy"
          access_scope = {
            namespaces = ["default"]
            type       = "namespace"
          }
        }
      }
    }
  }



  tags = {
    Environment = var.Environment
  }
}
##################################################


resource "aws_ecr_repository" "microservice" {
  name                 = var.aws_ecr_repository_name
  image_tag_mutability = var.image_tag_mutability

  tags = {
    Environment = var.Environment
  }
}

####################################################

data "aws_caller_identity" "current" {}

##################################################

output "aws_caller_identity_details" {
  value = data.aws_caller_identity.current
}

output "caller_arn" {
  value = data.aws_caller_identity.current.arn
}

output "all_azs" {
  value = module.vpc.azs
}

output "vpc_ID" {
  value = module.vpc.vpc_id
}
