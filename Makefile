# Makefile for managing the minimal-cost AWS EKS Terraform setup

# Variables (can be overridden)
AWS_CLI := $(shell command -v aws 2> /dev/null)
TERRAFORM := $(shell command -v terraform 2> /dev/null)
# Default node count when starting nodes
DEFAULT_NODE_COUNT := 1
# Default AWS Region (should match variables.tf or environment)
AWS_DEFAULT_REGION := $(shell aws configure get region || echo "us-east-1")


# Default target - shows help message
.PHONY: help
help:
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@echo "  setup        Check prerequisites (aws cli, terraform, AWS credentials/region)"
	@echo "  ver          Show versions of aws cli and terraform"
	@echo "  init         Initialize Terraform (terraform init)"
	@echo "  plan         Generate Terraform execution plan (terraform plan -var='node_group_desired_size=$(DEFAULT_NODE_COUNT)')"
	@echo "  apply        Apply Terraform configuration with default node count (terraform apply -var='node_group_desired_size=$(DEFAULT_NODE_COUNT)')"
	@echo "  destroy      Destroy ALL Terraform-managed infrastructure (terraform destroy)"
	@echo "  stop-nodes   Scale node group to 0 to reduce cost (terraform apply -var='node_group_desired_size=0')"
	@echo "  start-nodes  Scale node group to default size ($(DEFAULT_NODE_COUNT)) (terraform apply -var='node_group_desired_size=$(DEFAULT_NODE_COUNT)')"
	@echo "  kubeconfig   Generate kubectl config command"
	@echo "  fmt          Format Terraform code (terraform fmt)"
	@echo "  validate     Validate Terraform configuration (terraform validate)"

# Check prerequisites
.PHONY: setup
setup: check_aws_cli check_terraform check_aws_credentials
	@echo "==> Prerequisite checks passed (Commands found)."
	@echo "==> Ensure AWS Credentials and Region are configured correctly."
	@echo "    Current effective region: $(AWS_DEFAULT_REGION)"


check_aws_cli:
ifndef AWS_CLI
	@echo "Error: 'aws' command not found."
	@echo "Please install the AWS CLI: https://aws.amazon.com/cli/"
	@exit 1
endif

check_terraform:
ifndef TERRAFORM
	@echo "Error: 'terraform' command not found."
	@echo "Please install Terraform: https://developer.hashicorp.com/terraform/downloads"
	@exit 1
endif

check_aws_credentials:
	@echo "==> Checking AWS identity..."
	@$(AWS_CLI) sts get-caller-identity || (echo "Error: Failed to get AWS identity. Configure credentials (e.g., run 'aws configure' or set ENV vars)." && exit 1)


# Show versions
.PHONY: ver
ver: check_aws_cli check_terraform
	@echo "==> Checking versions..."
	@echo "--- AWS CLI ---"
	@$(AWS_CLI) --version
	@echo "--- Terraform ---"
	@$(TERRAFORM) version

# Initialize Terraform
# Downloads provider plugins and modules
.PHONY: init
init: setup
	@echo "==> Initializing Terraform..."
	@terraform init

# Generate Terraform execution plan
# Shows what changes Terraform will make
# Plans with default node count unless overridden
.PHONY: plan
plan: setup
	@echo "==> Generating Terraform execution plan (assuming $(DEFAULT_NODE_COUNT) node(s))..."
	@terraform plan -var="node_group_desired_size=$(DEFAULT_NODE_COUNT)"

# Apply Terraform configuration
# Creates or updates infrastructure. Requires confirmation.
# Applies with default node count unless overridden elsewhere (e.g., terraform.tfvars)
.PHONY: apply
apply: setup
	@echo "==> Applying Terraform configuration (setting node count to $(DEFAULT_NODE_COUNT))..."
	@terraform apply -var="node_group_desired_size=$(DEFAULT_NODE_COUNT)" -auto-approve

# Scale node group to 0
# Requires confirmation.
.PHONY: stop-nodes
stop-nodes: setup
	@echo "==> Scaling node group to 0..."
	@terraform apply -var="node_group_desired_size=0" -auto-approve

# Scale node group to default size
# Requires confirmation.
.PHONY: start-nodes
start-nodes: setup
	@echo "==> Scaling node group to $(DEFAULT_NODE_COUNT)..."
	@terraform apply -var="node_group_desired_size=$(DEFAULT_NODE_COUNT)" -auto-approve

# Destroy ALL Terraform-managed infrastructure
# Removes all resources defined in the configuration. Requires confirmation.
.PHONY: destroy
destroy: setup
	@echo "==> Destroying ALL Terraform infrastructure..."
	@terraform destroy -auto-approve

# Output command to configure kubectl
.PHONY: kubeconfig
kubeconfig:
	@echo "==> Run the following command to configure kubectl:"
	@terraform output -raw configure_kubectl

# Format Terraform code
# Rewrites configuration files to a canonical format
.PHONY: fmt
fmt: check_terraform
	@echo "==> Formatting Terraform code..."
	@terraform fmt -recursive

# Validate Terraform configuration
# Checks if the configuration is syntactically valid
.PHONY: validate
validate: check_terraform
	@echo "==> Validating Terraform configuration..."
	@terraform validate

