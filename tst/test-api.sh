#!/bin/bash
#
# API Testing Script for Porto Taxi API
# Usage: 
#   ./tst/test-api.sh              # Local mode (default)
#   TARGET=local ./tst/test-api.sh # Local mode (explicit)
#   TARGET=remote ./tst/test-api.sh # Remote mode (fetch from Terraform outputs)
#

set -e

TARGET="${TARGET:-local}"

# Configure based on target
if [ "$TARGET" = "remote" ]; then
    echo "=========================================="
    echo "Fetching remote configuration from Terraform..."
    echo "=========================================="
    
    # Change to iac directory to run terraform commands
    cd iac
    
    # Fetch values from Terraform outputs
    BASE_URL=$(terraform output -raw api_url 2>/dev/null)
    API_KEY=$(terraform output -raw api_key 2>/dev/null)
    VALID_GROUPS=$(terraform output -raw valid_groups 2>/dev/null)
    
    # Extract first group from comma-separated list
    GROUP_NAME=$(echo "$VALID_GROUPS" | cut -d',' -f1 | xargs)
    
    # Return to original directory
    cd ..
    
    if [ -z "$BASE_URL" ] || [ -z "$API_KEY" ] || [ -z "$GROUP_NAME" ]; then
        echo "Error: Failed to fetch Terraform outputs. Ensure infrastructure is deployed."
        exit 1
    fi
else
    # Local mode
    BASE_URL="${BASE_URL:-http://localhost:8000}"
    API_KEY="${API_KEY:-dev-key-12345}"
    GROUP_NAME="${GROUP_NAME:-dev-group}"
fi

echo "=========================================="
echo "Porto Taxi API - Test Suite"
echo "=========================================="
echo "Target: $TARGET"
echo "Base URL: $BASE_URL"
echo "API Key: ${API_KEY:0:8}..."
echo "Group: $GROUP_NAME"
echo ""

# Colours for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Colour

# Test counter
TESTS_PASSED=0
TESTS_FAILED=0

# Helper function to test endpoint
test_endpoint() {
    local name="$1"
    local method="$2"
    local endpoint="$3"
    local expected_status="$4"
    
    echo -n "Testing: $name ... "
    
    response=$(curl -s -w "\n%{http_code}" -X "$method" \
        -H "x-api-key: $API_KEY" \
        -H "x-group-name: $GROUP_NAME" \
        "$BASE_URL$endpoint")
    
    status_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | head -n-1)
    
    if [ "$status_code" -eq "$expected_status" ]; then
        echo -e "${GREEN}✓ PASS${NC} (HTTP $status_code)"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        
        # Pretty print JSON if jq is available
        if command -v jq &> /dev/null; then
            echo "$body" | jq '.' 2>/dev/null || echo "$body"
        else
            echo "$body"
        fi
    else
        echo -e "${RED}✗ FAIL${NC} (Expected $expected_status, got $status_code)"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        echo "$body"
    fi
    
    echo ""
}

# Run tests
echo "=========================================="
echo "System Endpoints"
echo "=========================================="
echo ""

test_endpoint "Health Check" "GET" "/health" 200

echo "=========================================="
echo "Authentication Tests"
echo "=========================================="
echo ""

# Test without headers
echo -n "Testing: Missing API key ... "
response=$(curl -s -w "\n%{http_code}" -X GET "$BASE_URL/drivers")
status_code=$(echo "$response" | tail -n1)
if [ "$status_code" -eq 401 ]; then
    echo -e "${GREEN}✓ PASS${NC} (HTTP $status_code)"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗ FAIL${NC} (Expected 401, got $status_code)"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi
echo ""

echo -n "Testing: Missing group name ... "
response=$(curl -s -w "\n%{http_code}" -X GET \
    -H "x-api-key: $API_KEY" \
    "$BASE_URL/drivers")
status_code=$(echo "$response" | tail -n1)
if [ "$status_code" -eq 401 ]; then
    echo -e "${GREEN}✓ PASS${NC} (HTTP $status_code)"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗ FAIL${NC} (Expected 401, got $status_code)"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi
echo ""

echo -n "Testing: Invalid group name ... "
response=$(curl -s -w "\n%{http_code}" -X GET \
    -H "x-api-key: $API_KEY" \
    -H "x-group-name: invalid-group" \
    "$BASE_URL/drivers")
status_code=$(echo "$response" | tail -n1)
if [ "$status_code" -eq 403 ]; then
    echo -e "${GREEN}✓ PASS${NC} (HTTP $status_code)"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗ FAIL${NC} (Expected 403, got $status_code)"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi
echo ""

echo -n "Testing: Invalid API key ... "
response=$(curl -s -w "\n%{http_code}" -X GET \
    -H "x-api-key: wrong-key" \
    -H "x-group-name: $GROUP_NAME" \
    "$BASE_URL/drivers")
status_code=$(echo "$response" | tail -n1)
if [ "$status_code" -eq 401 ]; then
    echo -e "${GREEN}✓ PASS${NC} (HTTP $status_code)"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗ FAIL${NC} (Expected 401, got $status_code)"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi
echo ""

echo "=========================================="
echo "Driver Endpoints"
echo "=========================================="
echo ""

test_endpoint "List Drivers (default)" "GET" "/drivers" 200
test_endpoint "List Drivers (limit 10)" "GET" "/drivers?limit=10" 200
test_endpoint "List Drivers (offset 50)" "GET" "/drivers?offset=50&limit=5" 200

echo "=========================================="
echo "Trip Endpoints"
echo "=========================================="
echo ""

test_endpoint "List Trips (default)" "GET" "/trips" 200
test_endpoint "List Trips (limit 10)" "GET" "/trips?limit=10" 200
test_endpoint "List Trips (offset 100)" "GET" "/trips?offset=100&limit=5" 200
test_endpoint "List Trips (filter by driver)" "GET" "/trips?driver_id=20000589&limit=5" 200
test_endpoint "List Trips (filter by date)" "GET" "/trips?date=1372636858&limit=5" 200
test_endpoint "List Trips (both filters)" "GET" "/trips?driver_id=20000589&date=1372636858&limit=5" 200
test_endpoint "List Trips (no results)" "GET" "/trips?driver_id=99999999" 404

# Summary
echo "=========================================="
echo "Test Summary"
echo "=========================================="
echo -e "Passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Failed: ${RED}$TESTS_FAILED${NC}"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed!${NC}"
    exit 1
fi
