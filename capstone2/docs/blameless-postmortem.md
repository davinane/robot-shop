# Blameless Postmortem: Robot Shop Web Outage

## Incident
Controlled Robot Shop web availability failure.

## Date
October 24, 2026

## Classification
Planned incident-response exercise.

## Summary
A controlled outage was introduced by scaling the Robot Shop
web deployment to zero replicas.

Prometheus Blackbox Exporter detected HTTP unavailability.
The RobotShopUnavailable alert entered the firing state.
The deployment was subsequently restored to one replica.

## Impact
The web endpoint was unavailable during the test.
Grafana displayed DOWN and recorded failed probes.

No verified customer transaction impact or data loss
was recorded as part of this exercise.

## Detection
Prometheus probe_success changed from 1 to 0.
Grafana displayed the failure.
RobotShopUnavailable entered the firing state.

## Root Cause
Intentional reduction of the web deployment to zero replicas
during the controlled incident drill.

This is the known cause of the simulated incident, not
evidence of an unplanned production defect.

## Mitigation
The web deployment was restored to its original replica count.

## Recovery Evidence
- Web deployment: 1/1 available
- Application pods: 12/12 running and ready
- probe_success: 1
- RobotShopUnavailable: inactive
- Alert rule health: ok

## What Worked
- Synthetic availability monitoring detected the outage
- The critical alert fired
- Kubernetes recovery succeeded
- Monitoring recognized recovery automatically

## Improvement Opportunities
- Verify external Slack alert delivery
- Add an operational runbook link to the alert
- Validate application-level tracing
- Capture exact detection and recovery timestamps
- Expand monitoring to real application requests and errors

## Follow-up Actions
1. Link runbook from the alert
2. Configure and test Slack notifications
3. Verify load generation and service metrics
4. Verify a real application request trace

## Blameless Principle
This was an intentionally introduced failure to validate
operational readiness. The review focuses on system
behavior, detection and recovery rather than individual blame.

## Evidence
- evidence/AlertFired.png
- evidence/failedRobotShop.png
- evidence/successDashboard.png
- docs/incident-drill-report.md
