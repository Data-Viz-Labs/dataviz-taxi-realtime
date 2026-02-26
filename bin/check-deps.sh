#!/bin/bash

# Dependency checker for Porto Taxi Simulation API
# Verifies all required tools are installed and properly configured

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Colour

echo "==================================="
echo "Checking dependencies..."
echo "==================================="
echo ""

MISSING_DEPS=0

# Check Python
echo -n "Checking Python 3.13+... "
if command -v python3 &> /dev/null; then
    PYTHON_VERSION=$(python3 --version | cut -d' ' -f2)
    PYTHON_MAJOR=$(echo $PYTHON_VERSION | cut -d'.' -f1)
    PYTHON_MINOR=$(echo $PYTHON_VERSION | cut -d'.' -f2)
    
    if [ "$PYTHON_MAJOR" -ge 3 ] && [ "$PYTHON_MINOR" -ge 13 ]; then
        echo -e "${GREEN}✓${NC} Found Python $PYTHON_VERSION"
    else
        echo -e "${RED}✗${NC} Python $PYTHON_VERSION found, but 3.13+ required"
        MISSING_DEPS=1
    fi
else
    echo -e "${RED}✗${NC} Not found"
    MISSING_DEPS=1
fi

# Check pip
echo -n "Checking pip... "
if command -v pip3 &> /dev/null; then
    PIP_VERSION=$(pip3 --version | cut -d' ' -f2)
    echo -e "${GREEN}✓${NC} Found pip $PIP_VERSION"
else
    echo -e "${RED}✗${NC} Not found"
    MISSING_DEPS=1
fi

# Check Docker or Podman
echo -n "Checking container runtime (Docker/Podman)... "
CONTAINER_CMD=""
if command -v docker &> /dev/null; then
    DOCKER_VERSION=$(docker --version | cut -d' ' -f3 | tr -d ',')
    echo -e "${GREEN}✓${NC} Found Docker $DOCKER_VERSION"
    CONTAINER_CMD="docker"
    
    # Check if Docker daemon is running
    if docker info &> /dev/null; then
        echo -e "  ${GREEN}✓${NC} Docker daemon is running"
    else
        echo -e "  ${YELLOW}⚠${NC} Docker daemon is not running"
    fi
elif command -v podman &> /dev/null; then
    PODMAN_VERSION=$(podman --version | cut -d' ' -f3)
    echo -e "${GREEN}✓${NC} Found Podman $PODMAN_VERSION"
    CONTAINER_CMD="podman"
    
    # Check if Podman is working
    if podman info &> /dev/null; then
        echo -e "  ${GREEN}✓${NC} Podman is working"
    else
        echo -e "  ${YELLOW}⚠${NC} Podman may not be properly configured"
    fi
else
    echo -e "${RED}✗${NC} Neither Docker nor Podman found"
    MISSING_DEPS=1
fi

# Check Terraform
echo -n "Checking Terraform... "
if command -v terraform &> /dev/null; then
    TERRAFORM_VERSION=$(terraform version -json | grep -o '"terraform_version":"[^"]*' | cut -d'"' -f4)
    echo -e "${GREEN}✓${NC} Found Terraform $TERRAFORM_VERSION"
else
    echo -e "${RED}✗${NC} Not found"
    MISSING_DEPS=1
fi

# Check AWS CLI
echo -n "Checking AWS CLI... "
if command -v aws &> /dev/null; then
    AWS_VERSION=$(aws --version | cut -d' ' -f1 | cut -d'/' -f2)
    echo -e "${GREEN}✓${NC} Found AWS CLI $AWS_VERSION"
    
    # Check AWS credentials
    if aws sts get-caller-identity &> /dev/null; then
        AWS_ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
        echo -e "  ${GREEN}✓${NC} AWS credentials configured (Account: $AWS_ACCOUNT)"
    else
        echo -e "  ${YELLOW}⚠${NC} AWS credentials not configured or invalid"
    fi
else
    echo -e "${RED}✗${NC} Not found"
    MISSING_DEPS=1
fi

# Check Kaggle API
echo -n "Checking Kaggle API... "
if command -v kaggle &> /dev/null; then
    echo -e "${GREEN}✓${NC} Found Kaggle CLI"
    
    # Check Kaggle credentials
    if [ -f "$HOME/.kaggle/kaggle.json" ]; then
        echo -e "  ${GREEN}✓${NC} Kaggle credentials found at ~/.kaggle/kaggle.json"
    else
        echo -e "  ${YELLOW}⚠${NC} Kaggle credentials not found at ~/.kaggle/kaggle.json"
        echo -e "  ${YELLOW}→${NC} Download from: https://www.kaggle.com/settings/account"
    fi
else
    echo -e "${YELLOW}⚠${NC} Not found (optional, can use curl instead)"
fi

# Check optional tools
echo ""
echo "Optional tools:"

echo -n "  Artillery (load testing)... "
if command -v artillery &> /dev/null; then
    ARTILLERY_VERSION=$(artillery version)
    echo -e "${GREEN}✓${NC} Found Artillery $ARTILLERY_VERSION"
else
    echo -e "${YELLOW}⚠${NC} Not found (install with: npm install -g artillery)"
fi

echo -n "  make... "
if command -v make &> /dev/null; then
    MAKE_VERSION=$(make --version | head -n1 | cut -d' ' -f3)
    echo -e "${GREEN}✓${NC} Found make $MAKE_VERSION"
else
    echo -e "${YELLOW}⚠${NC} Not found"
fi

# Summary
echo ""
echo "==================================="
if [ $MISSING_DEPS -eq 0 ]; then
    echo -e "${GREEN}All required dependencies are installed!${NC}"
    exit 0
else
    echo -e "${RED}Some required dependencies are missing.${NC}"
    echo "Please install missing tools before proceeding."
    exit 1
fi
