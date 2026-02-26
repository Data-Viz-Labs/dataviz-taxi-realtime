.PHONY: run build docker-run help

# Default values for local development
API_KEY ?= dev-key-12345
VALID_GROUPS ?= dev-group,test-group

help:
	@echo "Available targets:"
	@echo "  make run         - Run FastAPI application locally"
	@echo "  make build       - Build Docker image"
	@echo "  make docker-run  - Run Docker container locally"

run:
	@echo "Starting FastAPI server on http://localhost:8000"
	@echo "API Key: $(API_KEY)"
	@echo "Valid Groups: $(VALID_GROUPS)"
	@API_KEY=$(API_KEY) VALID_GROUPS=$(VALID_GROUPS) \
		uvicorn src.app:app --host 0.0.0.0 --port 8000 --reload

build:
	@echo "Building Docker image..."
	@docker build -f iac/assets/Dockerfile -t porto-taxi-api:latest .

docker-run:
	@echo "Running Docker container on http://localhost:8000"
	@docker run -p 8000:8000 \
		-v $(PWD)/data:/app/data \
		-e S3_BUCKET=$(S3_BUCKET) \
		-e API_KEY=$(API_KEY) \
		-e VALID_GROUPS=$(VALID_GROUPS) \
		porto-taxi-api:latest
