#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="robot-shop"
DEPLOYMENT="web"

ORIGINAL_REPLICAS=$(kubectl get deployment "$DEPLOYMENT" \
  -n "$NAMESPACE" -o jsonpath='{.spec.replicas}')

echo "Original web replicas: $ORIGINAL_REPLICAS"

restore() {
  echo "Restoring Robot Shop web deployment..."
  kubectl scale deployment "$DEPLOYMENT" \
    -n "$NAMESPACE" --replicas="$ORIGINAL_REPLICAS"
  kubectl rollout status deployment "$DEPLOYMENT" \
    -n "$NAMESPACE" --timeout=180s
}

trap restore EXIT

echo "===== SIMULATING WEB OUTAGE ====="
kubectl scale deployment "$DEPLOYMENT" \
  -n "$NAMESPACE" --replicas=0

kubectl rollout status deployment "$DEPLOYMENT" \
  -n "$NAMESPACE" --timeout=120s

echo "Web deployment scaled to zero."
echo "Waiting 4 minutes for monitoring and alert evaluation..."
sleep 240

echo "===== OUTAGE OBSERVATION COMPLETE ====="
echo "Check Grafana and Prometheus alerts now."

read -r -p "Press Enter to restore Robot Shop..."
