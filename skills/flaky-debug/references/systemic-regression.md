# Systemic-Regression Audit

Apply this audit when the evidence or causal chain meets any trigger:

- primary-key or already-indexed reads are slow in the same window as the
  blamed span;
- multiple unrelated endpoints, tests, or query shapes degrade together;
- latency or a timeout is attributed to transient, environmental, or
  infrastructure slowness without a named cause;
- degradation onset coincides with a deploy, migration, configuration change,
  or scheduled-job outcome change;
- a load-bearing quantity grows monotonically: table cardinality, queue depth,
  feed or cache size, retained fixtures, connection pressure.

Complete the audit before scoring root-cause confidence, terminating the
causal chain, or selecting the fix. When relational-database latency is also
in the chain, the [database access-path audit](./database-access-path.md) runs
as a branch of this audit, not instead of it.

## Audit

1. **Onset.** Date the first bad window and the last known-good window from
   telemetry, run history, or job logs. Name every change at that boundary:
   deploys, migrations, configuration, scheduled-job outcomes, data volume.
2. **Breadth.** Establish whether degradation is confined to the failing path
   or spans the service or environment: compare unrelated endpoints or query
   shapes in the same window against their pre-onset baseline.
3. **Invariant health.** For each maintenance process whose failure could
   produce the observed growth or degradation — cleanup, retention, TTL,
   compaction, backfill, scheduled jobs — record its last success before the
   failure window and its first failure. A silently failing maintenance job is
   a candidate terminal cause, not background noise.
4. **State growth.** Measure the suspect quantities (table cardinalities,
   queue depths, feed sizes, pool pressure) at the failure window and at the
   last known-good window.
5. **Classify.** *Path-local*: only the failing path degraded and the
   environment was healthy. *Systemic*: unrelated paths degraded together. For
   a systemic classification the terminal cause is the broken invariant or the
   boundary change, evidenced at the job, config, or log level — a broken
   operational invariant is a valid causal-chain terminus, and restoring it is
   a valid fix deliverable. A local code path that magnifies a systemic cause
   is an amplifier; record it as such, not as the root cause.

## Remediation boundary

A landed remediation — a restored maintenance job, data reset, capacity or
configuration repair, or an applied index migration — establishes an
activation boundary, exactly as a code fix's first fix-containing deployment
does. Record the boundary from evidence of the remediation taking effect
(first successful job run, applied migration), never from merge time. A code
fix to a deployed service requires evidence that the observed runtime contains
the fix: identify the running revision and verify its ancestry against the fix
revision. Merge time alone does not establish deployment. If an organization
profile supplies additional deployment-aware recurrence rules, apply them too.
The boundary rules below cover remediations that activate environment-wide.

- A sighting before an applicable boundary classifies
  `pre-remediation/stale-environment`: it is evidence about the degraded
  environment, not about the code path where it surfaced.
- A behavioral or architectural fix (retry, timeout, transaction restructuring,
  durable-job introduction, pool ownership) requires a same-mechanism sighting
  after every applicable boundary, or reproduction under a demonstrably
  healthy baseline. Injecting delay or failure into the code path chosen for
  hardening proves the hardening tolerates that fault; reproduction evidence
  must instead show the fault arising under a healthy environment.

Attach to the plan or report, one entry per applicable remediation:

```text
Remediation boundaries:
- remediation: <what was repaired> / <PR, run, or change reference>
- activation boundary: <timestamp and the evidence establishing it>
- sightings after boundary: <list or none>
- classification: <pre-remediation/stale-environment | post-boundary-recurrence>
```

## Intervention order

1. Restore broken operational invariants.
2. Repair missing access paths (indexes, schema).
3. Re-measure the healthy baseline.
4. Require a post-boundary recurrence.
5. Only then design local resilience or architectural hardening.

## Deliverable and completion criterion

Add a `Systemic regression audit` section to the plan or report with the
onset, breadth, invariant-health, and state-growth findings, the
path-local/systemic classification, and the remediation-boundary block for
every remediation that has landed. The audit is complete when every trigger
that fired is either explained by an evidenced terminal cause or explicitly
recorded as an open systemic unknown. While a correlated systemic regression
is unexplained, the chain is unterminated: cap confidence at 2/5 and keep
resilience, capacity, timeout, or transaction-boundary changes separate from
the unproven root fix. While every sighting predates an applicable remediation
boundary, the plan is stale: the deliverable is the post-boundary recurrence
check, not a code fix.
