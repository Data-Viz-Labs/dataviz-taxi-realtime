#!/bin/bash
#
# API Testing Script for Porto Taxi API
# Usage: ./tst/test-api.sh [base_url]
#

set -e

BASE_URL="${1:-http://localhost:8000}"
API_KEY="${API_KEY:-test-key}"
GROUP_NAME="${GROUP_NAME:-test-group}"

echo "=========================================="
echo "Porto Taxi API - Test Suite"
echo "=========================================="
echo "Base URL: $BASE_URL"
echo "API Key: $API_KEY"
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
