# Makefile for managing the free-tier GKE Terraform setup

# Variables (can be overridden)
GCLOUD := $(shell command -v gcloud 2> /dev/null)
TERRAFORM := $(shell command -v terraform 2> /dev/null)
# Terraform resource address for the primary node pool
NODE_POOL_TARGET := google_container_node_pool.primary_nodes

# Default target - shows help message
.PHONY: help
help:
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@echo "  setup        Check prerequisites (gcloud, terraform, GOOGLE_CLOUD_PROJECT, auth)"
	@echo "  ver          Show versions of gcloud and terraform"
	@echo "  init         Initialize Terraform (terraform init)"
	@echo "  plan         Generate Terraform execution plan (terraform plan)"
	@echo "  apply        Apply Terraform configuration (terraform apply)"
	@echo "  destroy      Destroy ALL Terraform-managed infrastructure (terraform destroy)"
	@echo "  stop-nodes   Destroy ONLY the GKE node pool to reduce cost (terraform destroy -target=...)"
	@echo "  start-nodes  Recreate ONLY the GKE node pool (terraform apply -target=...)"
	@echo "  fmt          Format Terraform code (terraform fmt)"
	@echo "  validate     Validate Terraform configuration (terraform validate)"

# Check prerequisites
.PHONY: setup
setup: check_gcloud check_terraform check_project_id check_auth
	@echo "==> Prerequisite checks passed (Commands found)."
	@echo "==> Ensure you have authenticated using 'gcloud auth application-default login'."
	@echo "==> Ensure GOOGLE_CLOUD_PROJECT environment variable is set correctly."

check_gcloud:
ifndef GCLOUD
	@echo "Error: 'gcloud' command not found."
	@echo "Please install the Google Cloud SDK: https://cloud.google.com/sdk/docs/install"
	@exit 1
endif

check_terraform:
ifndef TERRAFORM
	@echo "Error: 'terraform' command not found."
	@echo "Please install Terraform: https://developer.hashicorp.com/terraform/downloads"
	@exit 1
endif

check_project_id:
ifndef GOOGLE_CLOUD_PROJECT
	@echo "Warning: GOOGLE_CLOUD_PROJECT environment variable is not set."
	@echo "Set it using: export GOOGLE_CLOUD_PROJECT=\"your-gcp-project-id\""
	@echo "(Continuing, but Terraform might fail if project is not configured elsewhere)"
else
	@echo "==> GOOGLE_CLOUD_PROJECT is set to: $(GOOGLE_CLOUD_PROJECT)"
endif

check_auth:
	@echo "==> Reminder: Authenticate with GCP using 'gcloud auth application-default login' if you haven't already."


# Show versions
.PHONY: ver
ver: check_gcloud check_terraform
	@echo "==> Checking versions..."
	@echo "--- gcloud ---"
	@$(GCLOUD) version | grep "Google Cloud SDK"
	@echo "--- terraform ---"
	@$(TERRAFORM) version

# Initialize Terraform
# Downloads provider plugins
.PHONY: init
init: setup
	@echo "==> Initializing Terraform..."
	@terraform init

# Generate Terraform execution plan
# Shows what changes Terraform will make
.PHONY: plan
plan: setup
	@echo "==> Generating Terraform execution plan..."
	@terraform plan

# Apply Terraform configuration
# Creates or updates infrastructure. Requires confirmation.
.PHONY: apply
apply: setup
	@echo "==> Applying Terraform configuration..."
	@terraform apply

# Destroy ONLY the node pool (costly part)
# Leaves the cluster control plane and network resources. Requires confirmation.
.PHONY: stop-nodes
stop-nodes: setup
	@echo "==> Destroying ONLY the GKE node pool ($(NODE_POOL_TARGET))..."
	@terraform destroy -target=$(NODE_POOL_TARGET)

# Recreate ONLY the node pool
# Use this after 'stop-nodes' to bring the cluster back online. Requires confirmation.
# Note: Using -target for apply can be risky. Running 'make apply' might be safer
# as it ensures the rest of the configuration is also in the desired state.
.PHONY: start-nodes
start-nodes: setup
	@echo "==> Recreating ONLY the GKE node pool ($(NODE_POOL_TARGET))..."
	@terraform apply -target=$(NODE_POOL_TARGET)

# Destroy ALL Terraform-managed infrastructure
# Removes all resources defined in the configuration. Requires confirmation.
.PHONY: destroy
destroy: setup
	@echo "==> Destroying ALL Terraform infrastructure..."
	@terraform destroy

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

