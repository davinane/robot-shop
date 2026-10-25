# TS Academy DevOps Capstone 2: Keep It Running

## Stan's Robot Shop: Observability and Incident Response on AWS EKS

**Repository:** https://github.com/davinane/robot-shop  
**Course:** TS Academy DevOps, Modules 13–14  
**Environment:** AWS EKS (`ca-central-1`)  
**Cluster:** `ts-academy-capstone-eks`

## Overview

This project extends the Kubernetes environment from Capstone 1 by deploying Stan's Robot Shop and building an observability and incident-response workflow. It demonstrates steady traffic generation, metrics, searchable logs, application tracing, an availability service-level objective (SLO), Slack notifications, and a controlled outage and recovery.

### Capstone 2 requirements

- [x] Deploy Robot Shop and run a continuous load generator.
- [x] Collect metrics with Prometheus and build a Grafana dashboard for requests, errors, and latency.
- [x] Forward logs through Fluent Bit to Loki and search by service and error level.
- [x] Instrument the payment service with OpenTelemetry and find a request trace in Jaeger.
- [x] Define an availability SLO, error budget, and Slack alert.
- [x] Perform a controlled incident drill, recover the service, and document the outcome.

## Architecture

```text
Users -> AWS Load Balancer -> Robot Shop web
                                  |
                     catalogue / cart / payment / other services
                                  |
                       MongoDB / Redis / MySQL / RabbitMQ

Robot Shop and load generator (namespace: robot-shop)
                |
                +-- metrics / blackbox availability --> Prometheus --> Grafana
                |                                        |
                |                                        +--> Alertmanager --> Slack
                |
                +-- container logs --> Fluent Bit --> Loki --> Grafana Explore
                |
                +-- payment OTLP traces --> OpenTelemetry Collector --> Jaeger

Observability components (namespace: observability)
```

| Component | Technology | Purpose |
|---|---|---|
| Platform | AWS EKS, Kubernetes, Helm | Run Robot Shop and observability services |
| Load generation | Robot Shop load generator | Produce sustained application traffic |
| Metrics | Prometheus, blackbox probing | Measure requests, errors, latency and availability |
| Dashboards | Grafana | Visualize service behavior |
| Logging | Fluent Bit, Loki | Collect and search container logs |
| Tracing | OpenTelemetry, Jaeger | Trace payment HTTP requests |
| Alerting | Prometheus rules, Alertmanager, Slack | Notify on outages and recovery |

## Repository layout

| Path | Contents |
|---|---|
| `capstone2/robot-shop-values.yaml` | Robot Shop Helm overrides |
| `capstone2/load/load-deployment.yaml` | Load generator deployment |
| `capstone2/monitoring/prometheus-values.yaml` | kube-prometheus-stack Helm values and global AlertmanagerConfig reference |
| `capstone2/monitoring/dashboards/robot-shop-observability.json` | Grafana dashboard exported as code |
| `capstone2/monitoring/robot-shop-service-monitors.yaml` | Payment and cart ServiceMonitors |
| `capstone2/monitoring/robot-shop-slo-rules.yaml` | Availability SLO and alert rules |
| `capstone2/monitoring/robot-shop-slack-alertmanagerconfig.yaml` | Slack alert routing; no webhook credentials |
| `capstone2/tracing/otel-collector-values.yaml` | OpenTelemetry Collector configuration |
| `capstone2/docs/` | SLO policy, runbook, incident drill report, postmortem |
| `capstone2/evidence/` | Dashboard, log, trace and Slack screenshots |
| `payment/` | Payment application metrics and tracing instrumentation |

## Deploy and verify

**Prerequisites:** AWS credentials with access to the existing EKS cluster, `kubectl`, `helm`, and access to the Helm chart dependencies. These commands assume the EKS cluster is already provisioned. AWS resources incur charges.

```bash
aws eks update-kubeconfig --region ca-central-1 --name ts-academy-capstone-eks --profile terraform-capstone

helm upgrade --install robot-shop ./K8s/helm \
  --namespace robot-shop --create-namespace \
  -f capstone2/robot-shop-values.yaml

kubectl apply -f capstone2/load/load-deployment.yaml

helm upgrade --install monitoring prometheus-community/kube-prometheus-stack \
  --namespace observability --create-namespace \
  --version 92.12.0 \
  -f capstone2/monitoring/prometheus-values.yaml

kubectl get deployments,pods -n robot-shop
kubectl get pods -n observability
kubectl get alertmanager -n observability
```

The logging and tracing Helm releases are also deployed in `observability`. Their settings and manifests should be reviewed before reproducing the full environment from scratch. The commands above are not a complete one-command rebuild of all observability components.

### Grafana

```bash
kubectl port-forward -n observability svc/monitoring-grafana 3000:80
```

Open http://localhost:3000 and view the Robot Shop observability dashboard. Dashboard JSON: [`monitoring/dashboards/robot-shop-observability.json`](monitoring/dashboards/robot-shop-observability.json).

The dashboard includes application availability, payment HTTP request rate, 5xx rate, 5xx percentage, and p95 latency.

Example PromQL:

```promql
sum(rate(robot_shop_http_requests_total{namespace="robot-shop",service="payment",method="POST"}[5m]))
```

```promql
sum(rate(robot_shop_http_requests_total{namespace="robot-shop",service="payment",method="POST",status=~"5.."}[5m])) or vector(0)
```

```promql
histogram_quantile(0.95, sum by (le) (rate(robot_shop_http_request_duration_seconds_bucket{namespace="robot-shop",service="payment",method="POST"}[5m])))
```

## Centralized logging

Fluent Bit forwards Kubernetes logs to Loki. In Grafana Explore, use LogQL to filter payment logs:

```logql
{kubernetes_namespace_name="robot-shop",kubernetes_container_name="payment"}
```

Warnings:

```logql
{kubernetes_namespace_name="robot-shop",kubernetes_container_name="payment"} |= "WARNING"
```

Errors:

```logql
{kubernetes_namespace_name="robot-shop",kubernetes_container_name="payment"} |~ "ERROR|Traceback|HTTP/1.1 500"
```

Historical HTTP 500 errors and later validation warnings were observed in Loki. The payment service was updated to reject malformed cart requests with HTTP 400 rather than produce avoidable server errors.

## Distributed tracing

The payment service is instrumented with OpenTelemetry Flask instrumentation and exports traces through the OpenTelemetry Collector to Jaeger.

```bash
kubectl port-forward -n observability svc/jaeger 16686:16686
```

Open http://localhost:16686 and select `robot-shop-payment`.

A verified trace captured a successful `POST /pay/<id>` request, HTTP 200, approximately 301 ms, trace ID `c5885072414a132bcd95c38e5f6925b1`. This proves application-level tracing is working for the instrumented payment request.

**Limitation:** The Jaeger deployment uses ephemeral trace storage, so traces may disappear after a restart. Instrumentation of the other Robot Shop services was not part of this demonstration.

## Availability SLO and error budget

**SLO:** 99.9% HTTP availability over a rolling 30-day period.

At 30 days, the allowed downtime is `30 × 24 × 60 × 0.001 = 43.2 minutes`.

Alert rules include:

| Alert | Purpose |
|---|---|
| `RobotShopUnavailable` | Availability probe fails for at least 2 minutes |
| `RobotShopHighLatency` | HTTP probe latency remains elevated |
| `RobotShopAvailabilityBudgetBurn` | Availability budget is consumed too quickly |

See the [SLO and error-budget policy](docs/slo-error-budget-policy.md) and [alert rules](monitoring/robot-shop-slo-rules.yaml).

## Slack alerting

Prometheus sends alerts to Alertmanager. A global `AlertmanagerConfig` routes `RobotShop.*` alerts to `#robot-shop-alerts`, with FIRING and RESOLVED notifications enabled.

The configuration is stored in [`monitoring/robot-shop-slack-alertmanagerconfig.yaml`](monitoring/robot-shop-slack-alertmanagerconfig.yaml), and the Helm reference is in [`monitoring/prometheus-values.yaml`](monitoring/prometheus-values.yaml).

**Secret handling:** The webhook URL is stored in the Kubernetes Secret `robot-shop-slack-webhook` in namespace `observability`. It is deliberately not stored in Git. For a new cluster, create that Secret securely before enabling Slack alerting. Never print or commit the URL.

The real `RobotShopUnavailable` FIRING and RESOLVED Slack notifications were verified during the incident drill.

## Controlled incident drill

**Scenario:** Scale the Robot Shop web deployment from one replica to zero, observe the availability alert, then restore the original replica count.

> **Warning:** This intentionally interrupts the web application. Only perform it in an authorized test environment, and ensure you can restore the deployment.

```bash
kubectl scale deployment web -n robot-shop --replicas=0
```

After the Prometheus alert fired and Slack received the notification, the web deployment was restored:

```bash
kubectl scale deployment web -n robot-shop --replicas=1
kubectl rollout status deployment web -n robot-shop --timeout=180s
kubectl get deployment web -n robot-shop
kubectl get alertmanager -n observability
```

**Verified outcome:** The web deployment returned to `1/1`, Alertmanager was reconciled and available, and Slack received `RESOLVED: RobotShopUnavailable`.

Incident documents:

- [Incident drill report](docs/incident-drill-report.md)
- [Operational runbook](docs/robot-shop-runbook.md)
- [Blameless postmortem](docs/blameless-postmortem.md)

The `RobotShopUnavailable` alert rule includes a [runbook link](docs/robot-shop-runbook.md).

## Evidence

| Evidence | Screenshot |
|---|---|
| Application outage | [Failed Robot Shop](evidence/failedRobotShop.png) |
| Prometheus alert firing | [Alert fired](evidence/AlertFired.png) |
| Recovered dashboard | [Healthy dashboard](evidence/successDashboard.png) |
| Payment metrics | [Payment metrics](evidence/PaymentMetricsDashboardv2.png) |
| Loki payment errors | [Error logs](evidence/LokiPaymentErrors.png) |
| Loki payment warnings | [Warning logs](evidence/LokiPaymentWarnings.png) |
| Jaeger payment trace | [Payment trace](evidence/JaegerPaymentTrace.png) |
| Slack integration test | [Test notification](evidence/SlackAlertNotification.png) |
| Real outage notification | [FIRING](evidence/SlackRobotShopUnavailable.png) |
| Real recovery notification | [RESOLVED](evidence/SlackRobotShopResolved.png) |

## Lessons learned

1. **Metrics need application instrumentation.** Payment-specific request and latency measurements required Prometheus metrics in the application.
2. **Logs explain errors.** Loki exposed malformed-cart errors, helping distinguish input-validation failures from server defects.
3. **Traces provide request context.** OpenTelemetry and Jaeger made a successful payment request observable.
4. **Alert routing requires care.** An initially namespace-scoped AlertmanagerConfig did not match Robot Shop alerts. A global configuration with a child route fixed the mismatch and survived a Helm upgrade.
5. **Recovery is part of alerting.** Both FIRING and RESOLVED notifications were verified during the controlled incident.

## Operations and cleanup

```bash
kubectl get pods -n robot-shop
kubectl get pods -n observability
kubectl get prometheusrule -n observability
kubectl get alertmanager -n observability
```

AWS EKS control-plane resources, EC2 nodes, load balancers and storage may continue to incur charges. Tear down the environment after collecting the required evidence and completing the demo, following the Terraform state and infrastructure cleanup process.

## Submission

- **Project:** TS Academy DevOps Capstone 2, Keep It Running
- **Repository:** https://github.com/davinane/robot-shop
- **Implementation commit:** `be4c76c`
- **Deliverables:** Dashboard as code, logging and tracing configuration, SLO/error-budget policy, runbook, blameless postmortem, and screenshots of a working incident alert and recovery.
