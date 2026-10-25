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

## Reproducible observability installation

These instructions assume the Capstone 1 EKS cluster already exists, the AWS EBS CSI driver is configured, and the repository is checked out. They reproduce the documented components; the original deployment's exact Helm values for Loki, Fluent Bit and Jaeger must first be exported and committed as **non-secret** configuration. Do not claim a fully reproducible clean-cluster rebuild until those exports have been reviewed and tested.

### A. Capture the installed chart values (one-time preparation)

On the **existing working cluster**, export the *user-supplied* values (not `--all`, which includes large defaults) and verify the chart metadata:

```bash
aws eks update-kubeconfig --region ca-central-1 --name ts-academy-capstone-eks --profile terraform-capstone
mkdir -p capstone2/logging capstone2/tracing
helm list -n observability
helm get values loki -n observability -o yaml > capstone2/logging/loki-values.yaml
helm get values fluent-bit -n observability -o yaml > capstone2/logging/fluent-bit-values.yaml
helm get values jaeger -n observability -o yaml > capstone2/tracing/jaeger-values.yaml
```

**Security checkpoint:** Inspect these files locally before staging or pushing. Helm values may contain passwords, tokens, or endpoints. Remove secrets and replace them with Kubernetes Secret references or documented placeholders; confirm the sanitized values still deploy. The Slack webhook belongs only in the Kubernetes Secret, never in Git. The collector's maintained values already live at `capstone2/tracing/otel-collector-values.yaml`.

### B. Prepare chart repositories and namespace

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo add fluent https://fluent.github.io/helm-charts
helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
helm repo add jaegertracing https://jaegertracing.github.io/helm-charts
helm repo update
kubectl create namespace observability --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -f capstone2/gp3-storageclass.yaml
```

### C. Deploy logging and tracing in dependency order

These chart versions match the previously verified deployment. Run this block **after** exporting and reviewing the values files in Step A.

```bash
helm upgrade --install loki grafana/loki -n observability \
  --version 7.5.0 -f capstone2/logging/loki-values.yaml --wait --timeout 15m

helm upgrade --install fluent-bit fluent/fluent-bit -n observability \
  --version 0.58.3 -f capstone2/logging/fluent-bit-values.yaml --wait --timeout 10m

helm upgrade --install jaeger jaegertracing/jaeger -n observability \
  --version 4.16.1 -f capstone2/tracing/jaeger-values.yaml --wait --timeout 15m

helm upgrade --install otel-collector open-telemetry/opentelemetry-collector \
  -n observability --version 0.177.0 \
  -f capstone2/tracing/otel-collector-values.yaml --wait --timeout 10m
```

Loki requires its chart-specific single-binary and storage settings, which must be preserved in the exported values. Fluent Bit must retain its Kubernetes metadata enrichment and Loki output configuration. Jaeger uses ephemeral storage in this lab. The collector receives OTLP on ports 4317/4318 and exports traces to `jaeger.observability.svc.cluster.local:4317`.

### D. Deploy monitoring and Robot Shop integration

The global AlertmanagerConfig references a Secret that must exist **before** applying the Slack configuration. Create it from a securely supplied environment variable (never paste the URL into source files or command history):

```bash
kubectl create secret generic robot-shop-slack-webhook -n observability \
  --from-literal=webhook-url="$SLACK_WEBHOOK_URL" --dry-run=client -o yaml | kubectl apply -f -

helm upgrade --install monitoring prometheus-community/kube-prometheus-stack \
  -n observability --version 92.12.0 \
  -f capstone2/monitoring/prometheus-values.yaml --wait --timeout 15m

kubectl apply -f capstone2/monitoring/robot-shop-slack-alertmanagerconfig.yaml
kubectl apply -f capstone2/monitoring/robot-shop-service-monitors.yaml
kubectl apply -f capstone2/monitoring/robot-shop-slo-rules.yaml
```

The `SLACK_WEBHOOK_URL` variable must be populated securely before running this block. The Robot Shop Helm deployment and load-generator commands appear in the earlier **Deploy and verify** section. Ensure the payment image referenced by the Helm chart is available and that the payment service exports Prometheus metrics and OTLP traces.

### E. Verify each pipeline

```bash
helm list -n observability
kubectl get pods -n observability
kubectl get pods -n robot-shop
kubectl get servicemonitor,prometheusrule,alertmanagerconfig -n observability
kubectl get secret robot-shop-slack-webhook -n observability
kubectl get daemonset -n observability
```

Then verify in the UIs: Grafana metrics panels populate under load; Loki Explore returns payment logs; Jaeger returns a **new** payment request trace; and an authorized alert test reaches Slack. A healthy Helm release alone does not prove end-to-end observability.

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

## Instructor demo walkthrough

This is a short demonstration of the completed Capstone 2 requirements. Open separate terminals for port-forwards. Historical screenshots remain available if the ephemeral EKS environment has been shut down.

1. **Grafana (metrics):** Run `kubectl port-forward -n observability svc/monitoring-grafana 3000:80`, then open <http://localhost:3000>. Select the Robot Shop observability dashboard and explain application availability, payment request rate, HTTP 5xx rate and percentage, and p95 latency. Evidence: [payment metrics](evidence/PaymentMetricsDashboardv2.png).
2. **Loki (logs):** In Grafana **Explore**, select the Loki data source and query `{kubernetes_namespace_name="robot-shop",kubernetes_container_name="payment"} |= "WARNING"`. Then query `{kubernetes_namespace_name="robot-shop",kubernetes_container_name="payment"} |~ "ERROR|Traceback|HTTP/1.1 500"`. Explain how invalid-cart warnings differ from historical server errors. Evidence: [warnings](evidence/LokiPaymentWarnings.png) and [errors](evidence/LokiPaymentErrors.png).
3. **Jaeger (traces):** Run `kubectl port-forward -n observability svc/jaeger 16686:16686`, open <http://localhost:16686>, select service `robot-shop-payment`, and find a payment POST trace. A previously verified successful trace had ID `c5885072414a132bcd95c38e5f6925b1`, HTTP 200, and approximately 301 ms duration. Jaeger uses ephemeral storage, so use [saved trace evidence](evidence/JaegerPaymentTrace.png) if the old trace has expired.
4. **Slack (alert lifecycle):** Open the `#robot-shop-alerts` channel and show the real `RobotShopUnavailable` **FIRING** and **RESOLVED** messages from the controlled outage. Explain the path from the availability probe through Prometheus and Alertmanager to Slack. Evidence: [outage](evidence/SlackRobotShopUnavailable.png) and [recovery](evidence/SlackRobotShopResolved.png). Do not repeat the outage during a live demo unless explicitly authorized.

**Close with:** the [99.9% SLO and error-budget policy](docs/slo-error-budget-policy.md), [operational runbook](docs/robot-shop-runbook.md), and [blameless postmortem](docs/blameless-postmortem.md). The 30-day error budget is 43.2 minutes.

## Submission

- **Project:** TS Academy DevOps Capstone 2, Keep It Running
- **Repository:** https://github.com/davinane/robot-shop
- **Implementation commit:** `be4c76c`
- **Deliverables:** Dashboard as code, logging and tracing configuration, SLO/error-budget policy, runbook, blameless postmortem, and screenshots of a working incident alert and recovery.
