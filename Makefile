.PHONY: run help data-upload tf-init tf-plan tf-apply tf-destroy containers-build containers-reset containers-publish test-local test-remote test-load

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
	@echo ""
	@echo "Testing:"
	@echo "  make test-local          - Run API tests against localhost"
	@echo "  make test-remote         - Run API tests against deployed ALB"
	@echo "  make test-load           - Run Artillery load tests against ALB"

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
	@echo "Building container image..."
	@if command -v podman >/dev/null 2>&1; then \
		echo "Using Podman..."; \
		podman build -f iac/assets/Dockerfile -t porto-taxi-api:latest .; \
	elif command -v docker >/dev/null 2>&1; then \
		echo "Using Docker..."; \
		docker build -f iac/assets/Dockerfile -t porto-taxi-api:latest .; \
	else \
		echo "Error: Neither Docker nor Podman found"; \
		exit 1; \
	fi

containers-reset:
	@echo "Forcing ECS service update..."
	@CLUSTER=$$(cd iac && terraform output -raw ecs_cluster_name 2>/dev/null); \
	SERVICE_NORMAL=$$(cd iac && terraform output -raw ecs_service_normal_name 2>/dev/null); \
	SERVICE_SPOT=$$(cd iac && terraform output -raw ecs_service_spot_name 2>/dev/null); \
	if [ -z "$$CLUSTER" ] || [ -z "$$SERVICE_NORMAL" ] || [ -z "$$SERVICE_SPOT" ]; then \
		echo "Error: Infrastructure not deployed"; \
		exit 1; \
	fi; \
	echo "Updating service: $$SERVICE_NORMAL"; \
	aws ecs update-service --cluster $$CLUSTER --service $$SERVICE_NORMAL --force-new-deployment --region $(AWS_REGION); \
	echo "Updating service: $$SERVICE_SPOT"; \
	aws ecs update-service --cluster $$CLUSTER --service $$SERVICE_SPOT --force-new-deployment --region $(AWS_REGION); \
	echo "Services updated. New tasks will be deployed."

containers-publish:
	@echo "Publishing to ECR..."
	@ECR_URL=$$(cd iac && terraform output -raw ecr_repository_url 2>/dev/null) && \
	if [ -z "$$ECR_URL" ]; then \
		echo "Error: Run 'make tf-apply' first"; \
		exit 1; \
	fi && \
	./bin/publish_ecr.sh $$ECR_URL

test-local:
	@echo "Running API tests against localhost..."
	@chmod +x tst/test-api.sh
	@TARGET=local tst/test-api.sh

test-remote:
	@echo "Running API tests against deployed ALB..."
	@chmod +x tst/test-api.sh
	@TARGET=remote tst/test-api.sh

test-load:
	@echo "Running Artillery load tests..."
	@if ! command -v artillery >/dev/null 2>&1; then \
		echo "Error: Artillery not installed. Install with: npm install -g artillery"; \
		exit 1; \
	fi; \
	API_URL=$$(cd iac && terraform output -raw api_url 2>/dev/null); \
	API_KEY=$$(cd iac && terraform output -raw api_key 2>/dev/null); \
	VALID_GROUPS=$$(cd iac && terraform output -raw valid_groups 2>/dev/null); \
	GROUP_NAME=$$(echo $$VALID_GROUPS | cut -d',' -f1 | xargs); \
	if [ -z "$$API_URL" ] || [ -z "$$API_KEY" ] || [ -z "$$GROUP_NAME" ]; then \
		echo "Error: Infrastructure not deployed"; \
		exit 1; \
	fi; \
	echo "Target: $$API_URL"; \
	echo "Group: $$GROUP_NAME"; \
	API_URL=$$API_URL API_KEY=$$API_KEY GROUP_NAME=$$GROUP_NAME \
		artillery run tst/artillery.yml
