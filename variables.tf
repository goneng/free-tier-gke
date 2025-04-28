variable "aws_region" {
  description = "The AWS region to deploy resources."
  type        = string
  default     = "us-east-1" # Example default region
}

variable "cluster_name" {
  description = "Name of the EKS cluster."
  type        = string
  default     = "free-tier-eks"
}

variable "vpc_cidr_block" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "List of CIDR blocks for public subnets (for load balancers, etc.)."
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "List of CIDR blocks for private subnets (for EKS nodes, databases)."
  type        = list(string)
  default     = ["10.0.11.0/24", "10.0.12.0/24"]
}

variable "node_instance_type" {
  description = "EC2 instance type for EKS worker nodes (consider t3.micro/small for cost)."
  type        = string
  default     = "t3.micro" # Example: AWS Free Tier eligible instance type
}

variable "desired_node_count" {
  description = "Desired number of EKS worker nodes."
  type        = number
  default     = 1 # Start small for cost
}

variable "max_node_count" {
  description = "Maximum number of EKS worker nodes."
  type        = number
  default     = 2
}

variable "min_node_count" {
  description = "Minimum number of EKS worker nodes."
  type        = number
  default     = 1
}

# Add other variables here if you include other services like RDS, S3, etc.
/*
variable "db_instance_type" {
  description = "RDS database instance type (e.g., db.t3.micro for Free Tier)."
  type        = string
  default     = "db.t3.micro"
}

variable "db_name" {
  description = "Database name."
  type        = string
  default     = "mydatabase"
}
# ... add username, password variables (consider secrets management)
*/
