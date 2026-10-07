# Production-style distributed trace practice lab

This bundle extends the original Kubernetes debug lab with a realistic cross-pod correlation model for practising an incident scanner.

## Trace chain

`national_id -> flow_id -> session_id -> attestation_id -> original_id`

The intended service path is:

`customer-entry -> session-service -> attestation-service -> legacy-record-service -> payment-service`

Each hop should emit structured log lines containing the IDs it knows. The same transaction therefore appears across multiple pods and can be reconstructed chronologically.

## Recommended scanner exercise

1. Start the healthy baseline.
2. Generate traffic.
3. Search the first service for a known `national_id`.
4. Capture surrounding log context.
5. Extract newly discovered correlation IDs.
6. Search the next services using those IDs.
7. Continue until the trace stops or no new IDs are found.
8. Correlate timestamps, HTTP status, exceptions, Kubernetes events, restarts and readiness state.
9. Inject one incident at a time and repeat.

## Incident classes already present in the lab

- ImagePullBackOff
- CrashLoopBackOff
- readiness failure
- OOMKilled
- Service selector mismatch / no endpoints
- missing ConfigMap
- NetworkPolicy block
- Pending PVC
- liveness restart loop
- targetPort mismatch
- healthy baseline

The lab is disposable and intended for a local practice cluster. Do not run its failure scenarios against a production context.
