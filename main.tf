
# AWS Provider
provider "aws" {
  region = var.aws_region
}

# --- Networking ---

# VPC
resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr_block

  tags = {
    Name = "${var.cluster_name}-vpc"
  }
}

# Public Subnets
resource "aws_subnet" "public" {
  count             = length(var.public_subnet_cidrs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.public_subnet_cidrs[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.cluster_name}-public-subnet-${count.index}"
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
    "kubernetes.io/role/elb" = "1" # Tag required for AWS Load Balancer Controller
  }
}

# Private Subnets
resource "aws_subnet" "private" {
  count             = length(var.private_subnet_cidrs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = false # Nodes should not have public IPs

  tags = {
    Name = "${var.cluster_name}-private-subnet-${count.index}"
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
    "kubernetes.io/role/internal-elb" = "1" # Tag required for internal LBs
  }
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.cluster_name}-igw"
  }
}

# NAT Gateway (requires an Elastic IP and a public subnet)
resource "aws_eip" "nat" {
  vpc = true
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id # Place NAT GW in the first public subnet

  tags = {
    Name = "${var.cluster_name}-nat-gw"
  }

  # Required for AWS to properly find the NAT Gateway
  depends_on = [aws_internet_gateway.main]
}

# Route Table for Public Subnets
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.cluster_name}-public-rt"
  }
}

# Associate Public Route Table with Public Subnets
resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Route Table for Private Subnets
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id # Route internet traffic via NAT GW
  }

  tags = {
    Name = "${var.cluster_name}-private-rt"
  }
}

# Associate Private Route Table with Private Subnets
resource "aws_route_table_association" "private" {
  count          = length(aws_subnet.private)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

# Data source for Availability Zones in the selected region
data "aws_availability_zones" "available" {
  state = "available"
}

# --- IAM Roles for EKS ---

# EKS Cluster Role
resource "aws_iam_role" "eks_cluster_role" {
  name = "${var.cluster_name}-eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role_name  = aws_iam_role.eks_cluster_role.name
}

# EKS Node Group Role
resource "aws_iam_role" "eks_node_role" {
  name = "${var.cluster_name}-eks-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "eks_node_policy_1" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role_name  = aws_iam_role.eks_node_role.name
}

resource "aws_iam_role_policy_attachment" "eks_node_policy_2" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role_name  = aws_iam_role.eks_node_role.name
}

resource "aws_iam_role_policy_attachment" "eks_node_policy_3" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role_name  = aws_iam_role.eks_node_role.name
}


# --- EKS Cluster ---

resource "aws_eks_cluster" "main" {
  name     = var.cluster_name
  role_arn = aws_iam_role.eks_cluster_role.arn
  vpc_config {
    subnet_ids = [for s in aws_subnet.private : s.id]
  }

  # Add necessary K8s version, logging, etc.
  version = "1.28" # Specify your desired Kubernetes version

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy,
    aws_subnet.private,
    aws_subnet.public # EKS needs tags in both public and private subnets
  ]
}

# --- EKS Managed Node Group ---

resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_role_arn   = aws_iam_role.eks_node_role.arn
  subnet_ids      = [for s in aws_subnet.private : s.id] # Launch nodes in private subnets
  instance_types  = [var.node_instance_type]

  scaling_config {
    desired_size = var.desired_node_count
    max_size     = var.max_node_count
    min_size     = var.min_node_count
  }

  # Ensure the EKS cluster is created before the node group
  depends_on = [
    aws_iam_role_policy_attachment.eks_node_policy_1,
    aws_iam_role_policy_attachment.eks_node_policy_2,
    aws_iam_role_policy_attachment.eks_node_policy_3,
    aws_eks_cluster.main
  ]

  # Add disk size, labels, taints as needed
  # disk_size = 20 # Default is usually 20 GiB
}

# --- Add other AWS resources here (e.g., RDS, S3) ---

/*
# Example RDS instance (if you had a database in GCP)
resource "aws_db_instance" "default" {
  allocated_storage    = 20 # Check Free Tier limits
  storage_type         = "gp2"
  engine               = "mysql" # or postgres, etc.
  engine_version       = "8.0"
  instance_class       = var.db_instance_type # e.g., db.t3.micro
  name                 = var.db_name
  username             = "admin" # Replace with secure variable/secrets
  password             = "password" # Replace with secure variable/secrets
  identifier           = "${var.cluster_name}-db"
  skip_final_snapshot  = true
  vpc_security_group_ids = [aws_security_group.db.id] # Define a DB security group
  publicly_accessible  = false # Keep false for security
  db_subnet_group_name = aws_db_subnet_group.main.name # Define a DB subnet group

  # Ensure database is in private subnets
}

resource "aws_db_subnet_group" "main" {
  name       = "${var.cluster_name}-db-subnet-group"
  subnet_ids = [for s in aws_subnet.private : s.id]
  tags = {
    Name = "${var.cluster_name}-db-subnet-group"
  }
}

# Example S3 Bucket (if you had GCS)
resource "aws_s3_bucket" "my_bucket" {
  bucket = "${var.cluster_name}-bucket" # Bucket names must be globally unique

  tags = {
    Name = "${var.cluster_name}-bucket"
  }
}
*/
