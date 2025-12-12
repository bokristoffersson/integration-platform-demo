#!/bin/bash
# Comprehensive test suite for Redpanda cluster

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NAMESPACE="${REDPANDA_NAMESPACE:-infrastructure}"
CLUSTER_NAME="${REDPANDA_CLUSTER_NAME:-redpanda}"

echo "🧪 Redpanda Comprehensive Test Suite"
echo "===================================="
echo "Namespace: $NAMESPACE"
echo "Cluster: $CLUSTER_NAME"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

PASSED=0
FAILED=0

run_test() {
    local test_name="$1"
    local test_script="$2"
    
    echo -n "Running: $test_name... "
    if bash "$SCRIPT_DIR/$test_script" > /tmp/redpanda-test-$$.log 2>&1; then
        echo -e "${GREEN}✅ PASSED${NC}"
        ((PASSED++))
        return 0
    else
        echo -e "${RED}❌ FAILED${NC}"
        echo "   Error output:"
        sed 's/^/   /' /tmp/redpanda-test-$$.log
        ((FAILED++))
        return 1
    fi
}

# Test 1: Health Check
run_test "Cluster Health Check" "test-redpanda-health.sh"

# Test 2: HTTP API Basic
run_test "HTTP API Basic Test" "test-redpanda-http.sh"

# Test 3: Produce/Consume
run_test "Produce/Consume Test" "test-redpanda-produce-consume.sh"

# Summary
echo ""
echo "===================================="
echo "Test Summary:"
echo -e "  ${GREEN}Passed: $PASSED${NC}"
echo -e "  ${RED}Failed: $FAILED${NC}"
echo "===================================="

# Cleanup
rm -f /tmp/redpanda-test-$$.log

if [ $FAILED -eq 0 ]; then
    echo ""
    echo -e "${GREEN}✅ All tests passed!${NC}"
    exit 0
else
    echo ""
    echo -e "${RED}❌ Some tests failed${NC}"
    exit 1
fi

