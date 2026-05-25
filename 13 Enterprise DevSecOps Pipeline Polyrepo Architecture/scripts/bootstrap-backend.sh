#!/usr/bin/env bash
#
# bootstrap-backend.sh
# ====================
# One-time bootstrap script for Terraform remote state backend.
#
# THE CHICKEN-AND-EGG PROBLEM:
# ----------------------------
# Terraform needs a storage account to store its state file remotely.
# But we want to manage ALL infrastructure with Terraform. This creates
# a circular dependency: Terraform can't create the storage account it
# needs to store its own state, because it has nowhere to store state yet.
#
# THE SOLUTION:
# We break the cycle by provisioning the state backend OUTSIDE of Terraform
# using Azure CLI. This script runs once, manually, before the first
# `terraform init`. After that, Terraform manages everything else.
#
# The state backend lives in a SEPARATE resource group (rg-state-devsecops-dev)
# from the application infrastructure (rg-devsecops-dev). This ensures that
# destroying application infrastructure doesn't destroy the state file.
#
# IDEMPOTENCY:
# This script is safe to run multiple times. It checks for existing resources
# before creating them, so re-running won't fail or duplicate resources.
#
# USAGE:
#   chmod +x scripts/bootstrap-backend.sh
#   ./scripts/bootstrap-backend.sh
#
# PREREQUISITES:
#   - Azure CLI installed and authenticated (az login)
#   - Sufficient permissions to create resource groups and storage accounts
#

set -euo pipefail

# ==============================================================================
# Configuration
# ==============================================================================
RESOURCE_GROUP="rg-state-devsecops-dev"
STORAGE_ACCOUNT="stdevsecopsdev"
CONTAINER_NAME="tfstate"
LOCATION="southeastasia"

# ==============================================================================
# Helper Functions
# ==============================================================================

# Print an informational message
info() {
    echo "[INFO] $1"
}

# Print a success message
success() {
    echo "[OK]   $1"
}

# Print an error message and exit
error() {
    echo "[ERROR] $1" >&2
    exit 1
}

# ==============================================================================
# Pre-flight Checks
# ==============================================================================

# Verify Azure CLI is installed
if ! command -v az &> /dev/null; then
    error "Azure CLI (az) is not installed. Install it from https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
fi

# Verify the user is logged in to Azure
if ! az account show &> /dev/null; then
    error "Not logged in to Azure. Run 'az login' first."
fi

info "Azure CLI authenticated. Starting state backend bootstrap..."
echo ""

# ==============================================================================
# Step 1: Create Resource Group
# ==============================================================================

info "Checking if resource group '$RESOURCE_GROUP' exists..."

if az group show --name "$RESOURCE_GROUP" &> /dev/null; then
    success "Resource group '$RESOURCE_GROUP' already exists. Skipping creation."
else
    info "Creating resource group '$RESOURCE_GROUP' in '$LOCATION'..."
    az group create \
        --name "$RESOURCE_GROUP" \
        --location "$LOCATION" \
        --only-show-errors \
        --output none

    if [ $? -eq 0 ]; then
        success "Resource group '$RESOURCE_GROUP' created successfully."
    else
        error "Failed to create resource group '$RESOURCE_GROUP'."
    fi
fi

echo ""

# ==============================================================================
# Step 2: Create Storage Account
# - HTTPS-only: Ensures all traffic is encrypted in transit
# - No public blob access: Prevents accidental exposure of state files
#   (state files can contain sensitive outputs like connection strings)
# ==============================================================================

info "Checking if storage account '$STORAGE_ACCOUNT' exists..."

if az storage account show --name "$STORAGE_ACCOUNT" --resource-group "$RESOURCE_GROUP" &> /dev/null; then
    success "Storage account '$STORAGE_ACCOUNT' already exists. Skipping creation."
else
    info "Creating storage account '$STORAGE_ACCOUNT' (HTTPS-only, no public blob access)..."
    az storage account create \
        --name "$STORAGE_ACCOUNT" \
        --resource-group "$RESOURCE_GROUP" \
        --location "$LOCATION" \
        --sku "Standard_LRS" \
        --kind "StorageV2" \
        --https-only true \
        --allow-blob-public-access false \
        --min-tls-version "TLS1_2" \
        --only-show-errors \
        --output none

    if [ $? -eq 0 ]; then
        success "Storage account '$STORAGE_ACCOUNT' created successfully."
    else
        error "Failed to create storage account '$STORAGE_ACCOUNT'."
    fi
fi

echo ""

# ==============================================================================
# Step 3: Create Blob Container
# - This container holds the Terraform state file (devsecops.tfstate)
# - Azure Blob leases provide state locking automatically
# ==============================================================================

info "Checking if blob container '$CONTAINER_NAME' exists..."

# Get storage account key for container operations
ACCOUNT_KEY=$(az storage account keys list \
    --resource-group "$RESOURCE_GROUP" \
    --account-name "$STORAGE_ACCOUNT" \
    --query "[0].value" \
    --output tsv \
    --only-show-errors)

if [ -z "$ACCOUNT_KEY" ]; then
    error "Failed to retrieve storage account key for '$STORAGE_ACCOUNT'."
fi

CONTAINER_EXISTS=$(az storage container exists \
    --name "$CONTAINER_NAME" \
    --account-name "$STORAGE_ACCOUNT" \
    --account-key "$ACCOUNT_KEY" \
    --query "exists" \
    --output tsv \
    --only-show-errors)

if [ "$CONTAINER_EXISTS" = "true" ]; then
    success "Blob container '$CONTAINER_NAME' already exists. Skipping creation."
else
    info "Creating blob container '$CONTAINER_NAME'..."
    az storage container create \
        --name "$CONTAINER_NAME" \
        --account-name "$STORAGE_ACCOUNT" \
        --account-key "$ACCOUNT_KEY" \
        --only-show-errors \
        --output none

    if [ $? -eq 0 ]; then
        success "Blob container '$CONTAINER_NAME' created successfully."
    else
        error "Failed to create blob container '$CONTAINER_NAME'."
    fi
fi

echo ""

# ==============================================================================
# Summary
# ==============================================================================

echo "=============================================="
echo " State Backend Bootstrap Complete"
echo "=============================================="
echo ""
echo " Resource Group:   $RESOURCE_GROUP"
echo " Storage Account:  $STORAGE_ACCOUNT"
echo " Container:        $CONTAINER_NAME"
echo " Location:         $LOCATION"
echo ""
echo " Next steps:"
echo "   1. Note the storage account access key for GitHub Secrets:"
echo "      az storage account keys list \\"
echo "        --resource-group $RESOURCE_GROUP \\"
echo "        --account-name $STORAGE_ACCOUNT \\"
echo "        --query '[0].value' -o tsv"
echo ""
echo "   2. Add the key as 'ARM_ACCESS_KEY' in your GitHub repository secrets."
echo ""
echo "   3. Run 'terraform init' in the infra/ directory."
echo "=============================================="
