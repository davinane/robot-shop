# Robot Shop Incident Drill Report

## Project
TS Academy DevOps Capstone 2: Keep It Running

## Environment
- Cloud: AWS
- Region: ca-central-1
- Platform: Amazon EKS
- Application: Robot Shop
- Application namespace: robot-shop
- Observability namespace: observability

## Incident Scenario
Simulated unavailability of the Robot Shop web application.

## Failure Injection
The Kubernetes web deployment was temporarily scaled to zero replicas.

## Monitoring
- Prometheus
- Blackbox Exporter
- Grafana
- Loki and Fluent Bit

## Detection
The HTTP availability probe returned:

probe_success = 0

Grafana displayed the application as DOWN.

## Alert
The Prometheus alert RobotShopUnavailable entered the firing state.

Alert condition:

probe_success{job="robot-shop-availability"} == 0

Duration: 2 minutes.

## Recovery
The web deployment was restored to its original replica count.

Kubernetes verification:
- Web deployment: 1/1 available
- Application pods: 12/12 running and ready
- Web deployment rollout: successful

## Recovery Verification
Prometheus returned:

probe_success = 1

Alert state:
- RobotShopUnavailable: inactive
- Rule health: ok

## Outcome
PASS

The incident drill demonstrated successful failure detection,
alert activation, application restoration, and automatic alert recovery.

## Limitations
- Availability was measured using synthetic HTTP probes.
- The drill did not measure actual customer transaction latency.
- The configured 30-day SLOs have not yet been observed for a full 30 days.
- Alert notification delivery to an external channel was not tested.

## Evidence
- Grafana healthy dashboard screenshot
- Grafana DOWN dashboard screenshot
- Grafana firing alert screenshot
- Kubernetes deployment recovery output
- Prometheus probe and alert recovery output
