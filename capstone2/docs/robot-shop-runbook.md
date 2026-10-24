# Robot Shop Availability Incident Runbook

## Trigger
Prometheus alert: RobotShopUnavailable

Condition:
probe_success{job="robot-shop-availability"} == 0

Alert evaluation duration: 2 minutes.

## 1. Confirm the Alert

Check Grafana and Prometheus for:
- Current HTTP availability
- Failed probe history
- Recent changes
- Related application logs

## 2. Check Kubernetes Health

kubectl get pods -n robot-shop
kubectl get deployments -n robot-shop
kubectl get svc web -n robot-shop
kubectl get endpoints web -n robot-shop

## 3. Inspect the Web Deployment

kubectl describe deployment web -n robot-shop
kubectl get events -n robot-shop --sort-by=.lastTimestamp
kubectl logs deployment/web -n robot-shop --tail=100

## 4. Restore Service

Identify the failure before choosing a mitigation.

For an accidental scale-to-zero incident, restore the
previously recorded replica count.

Example, only if the expected count is one:

kubectl scale deployment/web -n robot-shop --replicas=1
kubectl rollout status deployment/web -n robot-shop --timeout=180s

Do not blindly scale unrelated services.

## 5. Verify Recovery

kubectl get deployment web -n robot-shop
kubectl get pods -n robot-shop

Confirm:
- probe_success returns 1
- Grafana displays UP
- RobotShopUnavailable becomes inactive
- Application requests succeed

## 6. Escalation

If the application remains unavailable:
- Inspect pod events and container logs
- Check database and dependency health
- Check Service endpoints and LoadBalancer
- Review recent configuration and Helm changes
- Escalate to the designated service owner

## 7. After Recovery

Record the incident timeline, cause, impact,
recovery actions and follow-up improvements.

Do not delete evidence during investigation.
