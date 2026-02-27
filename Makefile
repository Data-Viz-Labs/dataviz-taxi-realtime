.PHONY: run help data-upload tf-init tf-plan tf-apply tf-destroy containers-build containers-reset containers-publish

# Default values for local development
API_KEY ?= dev-key-12345
VALID_GROUPS ?= dev-group,test-group
AWS_REGION ?= eu-south-2

help:
	@echo "Available targets:"
	@echo ""
	@echo "Local Development:"
	@echo "  make run                 - Run FastAPI application locally"
	@echo ""
	@echo "Data Management:"
	@echo "  make data-upload         - Upload parquet files to S3"
	@echo ""
	@echo "Infrastructure:"
	@echo "  make tf-init             - Initialize Terraform"
	@echo "  make tf-plan             - Plan Terraform changes (builds Lambda)"
	@echo "  make tf-apply           - Deploy infrastructure (builds Lambda)"
	@echo "  make tf-destroy          - Destroy infrastructure"
	@echo ""
	@echo "Containers:"
	@echo "  make containers-build    - Build Docker image"
	@echo "  make containers-publish  - Build and push to ECR"
	@echo "  make containers-reset    - Force ECS service update"

run:
	@echo "Starting FastAPI server on http://localhost:8000"
	@echo "API Key: $(API_KEY)"
	@echo "Valid Groups: $(VALID_GROUPS)"
	@API_KEY=$(API_KEY) VALID_GROUPS=$(VALID_GROUPS) \
		uvicorn src.app:app --host 0.0.0.0 --port 8000 --reload

data-upload:
	@echo "Uploading data to S3..."
	@BUCKET=$$(cd iac && terraform output -raw s3_bucket_name 2>/dev/null) && \
	if [ -z "$$BUCKET" ]; then \
		echo "Error: Run 'make tf-apply' first"; \
		exit 1; \
	fi && \
	aws s3 cp data/trips_memory.parquet s3://$$BUCKET/data/ && \
	aws s3 cp data/drivers_memory.parquet s3://$$BUCKET/data/ && \
	echo "Data uploaded to s3://$$BUCKET/data/"

tf-init:
	@echo "Initializing Terraform..."
	@cd iac && terraform init

tf-plan:
	@echo "Planning Terraform changes..."
	@cd iac && terraform plan

tf-apply:
	@echo "Deploying infrastructure..."
	@cd iac && terraform apply -auto-approve
	@echo ""
	@echo "=========================================="
	@echo "Deployment Complete!"
	@echo "=========================================="
	@cd iac && terraform output
	@echo ""
	@echo "To get the API key:"
	@echo "  cd iac && terraform output -raw api_key"

tf-destroy:
	@echo "Cleaning up AWS resources..."
	@./bin/cleanup-aws.sh
	@echo ""
	@echo "Destroying infrastructure..."
	@cd iac && terraform destroy -auto-approve
containers-build:
	@echo "Building Docker image..."
	@docker build -f iac/assets/Dockerfile -t porto-taxi-api:latest .

containers-reset:
	@echo "Forcing ECS service update..."
	@CLUSTER=$$(cd iac && terraform output -raw ecs_cluster_name 2>/dev/null) && \
	if [ -z "$$CLUSTER" ]; then \
		echo "Error: Infrastructure not deployed"; \
		exit 1; \
	fi && \
	aws ecs update-service --cluster $$CLUSTER --service porto-taxi-prod-normal --force-new-deployment --region $(AWS_REGION) && \
	aws ecs update-service --cluster $$CLUSTER --service porto-taxi-prod-spot --force-new-deployment --region $(AWS_REGION) && \
	echo "Services updated. New tasks will be deployed."

containers-publish:
	@echo "Publishing to ECR..."
	@ECR_URL=$$(cd iac && terraform output -raw ecr_repository_url 2>/dev/null) && \
	if [ -z "$$ECR_URL" ]; then \
		echo "Error: Run 'make tf-apply' first"; \
		exit 1; \
	fi && \
	./bin/publish_ecr.sh $$ECR_URL
