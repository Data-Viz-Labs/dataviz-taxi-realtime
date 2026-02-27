#!/bin/bash
#
# Publish Docker image to ECR
# Usage: ./bin/publish_ecr.sh [ecr_repository_url]
#
# Supports both Docker and Podman
#

set -e

ECR_REPO="${1}"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

if [ -z "$ECR_REPO" ]; then
    echo "Error: ECR repository URL required"
    echo "Usage: $0 <ecr_repository_url>"
    exit 1
fi

# Detect container runtime (Docker or Podman)
if command -v docker &> /dev/null; then
    CONTAINER_CMD="docker"
elif command -v podman &> /dev/null; then
    CONTAINER_CMD="podman"
else
    echo "Error: Neither Docker nor Podman found"
    echo "Please install Docker or Podman"
    exit 1
fi

echo "=========================================="
echo "Publishing to ECR"
echo "=========================================="
echo "Container runtime: $CONTAINER_CMD"
echo "Repository: $ECR_REPO"
echo "Timestamp: $TIMESTAMP"
echo ""

# Extract region from ECR URL
REGION=$(echo "$ECR_REPO" | cut -d'.' -f4)

# Login to ECR
echo "Logging in to ECR..."
aws ecr get-login-password --region "$REGION" | \
    $CONTAINER_CMD login --username AWS --password-stdin "$ECR_REPO"

# Build image
echo "Building container image..."
$CONTAINER_CMD build -f iac/assets/Dockerfile -t porto-taxi-api:latest .

# Tag images
echo "Tagging images..."
$CONTAINER_CMD tag porto-taxi-api:latest "$ECR_REPO:latest"
$CONTAINER_CMD tag porto-taxi-api:latest "$ECR_REPO:$TIMESTAMP"

# Push images
echo "Pushing images to ECR..."
$CONTAINER_CMD push "$ECR_REPO:latest"
$CONTAINER_CMD push "$ECR_REPO:$TIMESTAMP"

echo ""
echo "=========================================="
echo "Published successfully!"
echo "=========================================="
echo "Latest: $ECR_REPO:latest"
echo "Tagged: $ECR_REPO:$TIMESTAMP"
