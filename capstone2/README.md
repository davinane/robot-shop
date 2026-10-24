# TS Academy DevOps Capstone 2
## Keep It Running: Robot Shop Observability on AWS EKS

### Project Overview

This project deploys the Robot Shop microservices application
to Amazon EKS and implements an observability and incident-response
solution using Prometheus, Grafana, Loki, Fluent Bit,
OpenTelemetry Collector, and Jaeger.

### Architecture

Application:
- AWS EKS in ca-central-1
- Robot Shop microservices
- Kubernetes Deployments and StatefulSet
- AWS LoadBalancer
- Amazon EBS gp3 persistent storage

Monitoring:
- Prometheus Operator
- Prometheus
- Blackbox Exporter
- PrometheusRule alerts
- Grafana dashboards

Logging:
- Fluent Bit
- Loki
- Grafana Explore

Tracing:
- OpenTelemetry Collector
- Jaeger

### Application Deployment

Namespace: robot-shop

The deployment includes 12 application pods:

- cart
- catalogue
- dispatch
- mongodb
- mysql
- payment
- rabbitmq
- ratings
- redis
- shipping
- user
- web

### Observability

Namespace: observability

Prometheus monitors the Robot Shop web endpoint using
Blackbox Exporter every 30 seconds.

Metrics include:
- probe_success
- probe_http_status_code
- probe_duration_seconds

### Service Level Objectives

Availability objective:
99.9% successful HTTP probes over 30 days.

Synthetic latency objective:
95% of HTTP probes completing within one second over 30 days.

These are configured objectives. A full 30-day observation
period has not yet been completed.

### Alerting

Configured Prometheus alerts:

1. RobotShopUnavailable
2. RobotShopHighLatency
3. RobotShopAvailabilityBudgetBurn

The RobotShopUnavailable alert fires when the HTTP
availability probe fails continuously for two minutes.

### Logging

Fluent Bit collects Kubernetes container logs and forwards
them to Loki.

Grafana provides log exploration and dashboard visualization.

### Distributed Tracing

OpenTelemetry Collector exports traces to Jaeger.

A synthetic OTLP trace was successfully submitted and
retrieved from Jaeger.

End-to-end tracing from the Robot Shop application services
has not yet been verified.

### Incident Drill

A controlled outage was simulated by scaling the Robot Shop
web deployment to zero replicas.

Observed results:

- Grafana availability changed from UP to DOWN.
- Prometheus detected the failed HTTP probes.
- RobotShopUnavailable entered the firing state.
- The web deployment was restored.
- All 12 application pods returned to healthy status.
- Prometheus reported probe_success = 1.
- RobotShopUnavailable returned to inactive.

Result: PASS

### Project Files

- monitoring/: Prometheus, Grafana, SLOs and probe configuration
- logging/: Loki and Fluent Bit configuration
- tracing/: Jaeger and OpenTelemetry Collector configuration
- docs/: Incident reports and supporting documentation

### Limitations

- HTTP availability is measured synthetically.
- Actual customer transaction latency is not measured.
- SLO compliance has not been evaluated over a full 30 days.
- External alert notification delivery was not tested.
- Application-level distributed tracing remains unverified.
- Jaeger uses ephemeral in-memory trace storage.

### Cleanup

The AWS EKS cluster, EC2 worker nodes, LoadBalancer,
and EBS volumes may incur charges.

Destroy the infrastructure after collecting all required
capstone evidence.
