#!/bin/bash
#
# Cleanup AWS resources before Terraform destroy
# Usage: ./bin/cleanup-aws.sh
#

set -e

REGION="${AWS_REGION:-eu-south-2}"

echo "=========================================="
echo "Cleaning up AWS resources"
echo "=========================================="
echo "Region: $REGION"
echo ""

# Get bucket name from Terraform
BUCKET=$(cd iac && terraform output -raw s3_bucket_name 2>/dev/null || echo "")

if [ -n "$BUCKET" ]; then
    echo "Emptying S3 bucket: $BUCKET"
    aws s3 rm s3://$BUCKET --recursive --region $REGION 2>/dev/null || true
    echo "S3 bucket emptied"
else
    echo "No S3 bucket found in Terraform state"
fi

# Get ECR repository from Terraform
ECR_REPO=$(cd iac && terraform output -raw ecr_repository_url 2>/dev/null | cut -d'/' -f2 || echo "")

if [ -n "$ECR_REPO" ]; then
    echo "Deleting ECR images from: $ECR_REPO"
    
    # List and delete all images
    IMAGE_IDS=$(aws ecr list-images --repository-name $ECR_REPO --region $REGION --query 'imageIds[*]' --output json 2>/dev/null || echo "[]")
    
    if [ "$IMAGE_IDS" != "[]" ]; then
        aws ecr batch-delete-image \
            --repository-name $ECR_REPO \
            --region $REGION \
            --image-ids "$IMAGE_IDS" 2>/dev/null || true
        echo "ECR images deleted"
    else
        echo "No ECR images to delete"
    fi
else
    echo "No ECR repository found in Terraform state"
fi

echo ""
echo "=========================================="
echo "Cleanup complete!"
echo "=========================================="
