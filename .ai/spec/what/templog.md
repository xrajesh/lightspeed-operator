# Temporary Audit Log Storage — Operator

Implementation details for the lightspeed-operator's role in the templog feature. See parent spec `what/templog.md` for requirements and architecture.

## Behavioral Rules

### CRD

1. `OLSConfig.spec.templog` is a boolean field. Default: `true`. Controls whether the Collector's postgres exporter is active.
2. `OLSConfig.spec.audit.otel.endpoint` is an optional string field. When set, the Collector forwards traces to this endpoint.
3. All audit, tracing, and templog configuration lives on `OLSConfig`. `AgenticOLSConfig` has no telemetry fields.

### PostgreSQL Bootstrap

4. The Postgres bootstrap script always creates the `templogs` schema alongside the existing `quota` and `conversation_cache` schemas (regardless of `spec.templog` value).
5. The bootstrap script creates the `templogs.logs` table and `idx_logs_trace_id` index (see parent spec for DDL).

### Collector Deployment (Always On)

6. The operator always deploys a single-replica Deployment for the custom OTel Collector using the `lightspeed-otel-collector` container image.
7. The Collector Deployment follows the same management patterns as PostgreSQL: operator-managed image reference, resource requirements, tolerations, node selectors.
8. The operator creates a Service exposing port 4317 (OTLP gRPC) for the Collector.
9. The operator creates a ConfigMap containing the Collector configuration (YAML). The configuration is generated based on `OLSConfig`:
   - When `spec.templog: true` (or absent): logs pipeline includes the `postgresexporter`
   - When `spec.templog: false`: logs pipeline has no active exporter
   - When `spec.audit.otel.endpoint` is set: traces pipeline includes `otlpexporter` pointing at that endpoint
   - When `spec.audit.otel.endpoint` is absent: no traces pipeline
10. The Postgres DSN in the Collector configuration uses the same credentials secret the operator already manages for PostgreSQL.
11. The operator creates a NetworkPolicy allowing ingress to the Collector on port 4317 from agentic-operator and sandbox pods only.
12. TLS between the Collector and PostgreSQL uses the existing service-ca certificates.
13. The operator regenerates and remounts the Collector ConfigMap when `OLSConfig` changes. Changes trigger a Collector restart via resource version annotation tracking.

### Agentic Pod Wiring

14. The operator always sets an environment variable on agentic-operator and sandbox pods with the Collector's OTLP endpoint: `<collector-service>.<namespace>.svc:4317`. This is always set because the Collector is always deployed.
15. The operator sets an environment variable on agentic-operator and sandbox pods indicating whether audit is enabled (from `OLSConfig.spec.audit.enabled`).
16. The operator sets an environment variable on agentic-operator pods indicating whether templog is enabled (from `OLSConfig.spec.templog`), so the agentic-operator knows whether to add the templog-cleanup finalizer to new AgenticRuns.

## Configuration Surface

| Field path | Description |
|---|---|
| `spec.templog` | Boolean. Controls whether the Collector writes logs to PostgreSQL. Default: `true`. |
| `spec.audit.enabled` | Boolean. Controls whether audit events are emitted by components. Default: `true`. |
| `spec.audit.otel.endpoint` | String. External tracing endpoint. Collector forwards traces here when set. |

## Constraints

1. The Collector is always deployed as a single replica. It cannot be disabled.
2. The Collector image reference is managed by the operator (not user-configurable).
3. The `templogs` schema is always created and never dropped by the operator.

## Cross-References

- Parent spec: `what/templog.md`
- `what/postgres.md` — PostgreSQL deployment, bootstrap script
- `what/crd-api.md` — `OLSConfig` CRD fields
