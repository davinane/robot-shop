#!/usr/bin/env bash
set -euo pipefail

NS=observability
COLLECTOR=otel-collector-opentelemetry-collector
TRACE_ID=$(openssl rand -hex 16)
SPAN_ID=$(openssl rand -hex 8)
START_NS=$(($(date +%s) * 1000000000))
END_NS=$((START_NS + 100000000))

echo "Trace ID: $TRACE_ID"

cat > /tmp/robot-shop-test-trace.json <<JSON
{
  "resourceSpans": [
    {
      "resource": {
        "attributes": [
          {
            "key": "service.name",
            "value": {"stringValue": "robot-shop-capstone-test"}
          }
        ]
      },
      "scopeSpans": [
        {
          "scope": {"name": "capstone-verification"},
          "spans": [
            {
              "traceId": "$TRACE_ID",
              "spanId": "$SPAN_ID",
              "name": "verify-otel-to-jaeger",
              "kind": 1,
              "startTimeUnixNano": "$START_NS",
              "endTimeUnixNano": "$END_NS"
            }
          ]
        }
      ]
    }
  ]
}
JSON

echo "===== SEND TEST TRACE ====="

kubectl -n "$NS" port-forward \
  "svc/$COLLECTOR" 14318:4318 \
  >/tmp/capstone-otel-portforward.log 2>&1 &

PF_PID=$!
trap 'kill "$PF_PID" 2>/dev/null || true' EXIT

sleep 4

curl -fsS \
  -X POST \
  http://127.0.0.1:14318/v1/traces \
  -H 'Content-Type: application/json' \
  --data-binary @/tmp/robot-shop-test-trace.json

echo
echo "===== TRACE SUBMITTED ====="
echo "Trace ID: $TRACE_ID"
echo "Service: robot-shop-capstone-test"
echo
echo "Check Jaeger for this service and trace."
