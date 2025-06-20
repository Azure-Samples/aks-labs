#!/bin/bash

# Test script for Ray Serve MNIST model endpoint
# Usage: ./test-model.sh [blank|sample]

# Default to blank image test
TEST_TYPE="${1:-blank}"

# Check if port-forward is running
if ! curl -s http://localhost:8000/mnist/health > /dev/null 2>&1; then
    echo "❌ Error: Ray Serve endpoint not accessible at localhost:8000/mnist"
    echo "Please ensure port-forward is running:"
    echo "kubectl port-forward -n \$RAY_NAMESPACE service/ray-serve-mnist-svc 8000:8000"
    exit 1
fi

echo "🧪 Testing MNIST model endpoint with $TEST_TYPE image..."

case $TEST_TYPE in
    "blank")
        echo "📝 Sending blank (all zeros) 28x28 image..."
        PAYLOAD='{"data": '$(cat $(dirname "$0")/test-data.json | jq '.examples.blank_image.data')'}'
        ;;
    "sample")
        echo "📝 Sending sample pattern 28x28 image..."
        PAYLOAD='{"data": '$(cat $(dirname "$0")/test-data.json | jq '.examples.sample_digit.data')'}'
        ;;
    *)
        echo "❌ Invalid test type. Use 'blank' or 'sample'"
        exit 1
        ;;
esac

echo "🚀 Making request to Ray Serve endpoint..."
response=$(curl -s -X POST http://localhost:8000/mnist \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD")

if [ $? -eq 0 ]; then
    echo "✅ Response received:"
    echo "$response" | jq '.'
else
    echo "❌ Request failed"
    exit 1
fi
