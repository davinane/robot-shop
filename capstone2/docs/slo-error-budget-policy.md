# Robot Shop SLO and Error Budget Policy

## Service
Robot Shop web application on AWS EKS.

## Service Level Indicator (SLI)
HTTP availability measured by Prometheus Blackbox Exporter.

A successful probe returns probe_success = 1.
An unsuccessful probe returns probe_success = 0.

Probe interval: 30 seconds.

## Availability SLO
99.9% successful HTTP probes over a rolling 30-day window.

## Error Budget
30 days = 43,200 minutes.
Allowed unavailability = 0.1%.
Equivalent downtime budget = 43.2 minutes.
Equivalent failed probes = 86.4.

The operational calculation uses observed valid probe samples.
Missing probe data must be investigated and not silently treated
as either success or failure.

## Additional Latency Objective
95% of successful synthetic HTTP probes should complete
within one second over 30 days.

This is not a measurement of real user transaction latency.

## Budget Consumption
Budget consumed = failed valid probes / expected valid probes
for the reporting window, subject to data completeness.

## Response Policy
0-25% consumed:
Continue normal operations and review weekly.

25-50% consumed:
Investigate reliability trends and recurring failures.

50-75% consumed:
Prioritize reliability improvements over nonessential changes.

75-100% consumed:
Escalate to the service owner, review risky releases,
and prepare a mitigation plan.

100% or more consumed:
Pause nonessential production releases until the service
owner approves resumption based on recovery evidence
and documented risk assessment.

Emergency security and reliability fixes remain permitted.

## Incident Handling
Critical availability alerts require immediate investigation.
Restore service first, then investigate the cause.

Document the incident and review corrective actions.

## Measurement Limitations
The SLI measures synthetic web endpoint availability.
It does not measure every Robot Shop business transaction.
A full 30-day measurement period has not yet elapsed.

Controlled drills are included unless explicitly excluded
under a documented, approved measurement policy.
