# Database Access-Path Audit

This audit is a branch of the
[systemic-regression audit](./systemic-regression.md); when any of that
audit's triggers also fires, complete both audits.

Apply this branch when relational database latency or a database timeout appears
in the causal chain. Audit the three slowest individual datastore spans on the
failing critical path, every individual span that consumes at least 10% of the
failed request or transaction, and every normalized query shape whose repeated
executions consume at least 10% of the failed request or transaction duration in
aggregate. Complete it before scoring root-cause confidence or selecting the
fix.

## Audit

1. Recover the executed SQL shape from telemetry or reconstruct it from the ORM
   call. Normalize and group repeated executions; record call count, aggregate
   duration, filter predicate structure and parameter types, joins, ordering,
   grouping, and limits. Redact raw filter values from plans and reports,
   including PII, PHI, tokens, and tenant identifiers.
2. Inspect the schema and migrations present in the observed runtime. Match each
   predicate and ordering requirement to an index, accounting for composite
   leftmost prefixes, sort direction, partial predicates, and selectivity. In
   PostgreSQL, a foreign key does not automatically index its referencing
   column.
3. Obtain `EXPLAIN (ANALYZE, BUFFERS)` against representative data when safe.
   Use plain `EXPLAIN` when executing the statement would be unsafe. If database
   access is unavailable, record the static schema evidence and the missing plan
   evidence instead of assuming the access path.
4. Use the plan and cardinality to evaluate any candidate index. Account for
   expected read benefit, write and storage cost, overlap with existing indexes,
   and online or concurrent migration safety.
5. Estimate the indexed counterfactual from the plan, representative data, or a
   comparable indexed query. Compare that latency with the failed request or
   transaction budget; do not model the query as taking zero time.
6. Classify each query's evidenced role: trigger, amplifier, failure mechanism,
   unrelated, or more than one. Keep a shared slowdown and an unindexed
   amplifier as simultaneous explanations when the evidence supports both, and
   state when removing an amplifier would still have prevented the failure.
7. After finding a missing index, inspect up to five other query shapes against
   the same table or model. Prioritize shapes observed in the same failure
   window by aggregate duration, then current-code call sites. Check whether
   each selected shape's predicates and ordering have supporting indexes.

## Deliverable and completion criterion

Add a `Database access-path audit` section to the plan or report:

| Query shape | Calls, duration, and critical-path share | Predicate / ordering | Index and plan evidence | Counterfactual and causal role |
| --- | --- | --- | --- | --- |

The audit is complete when every selected span or aggregate query-shape group
has a row and every proposed index is supported or rejected by the evidence
above. Until then, treat a relational-database latency claim such as "the
database or infrastructure was slow" as an unterminated causal-chain link: cap
confidence at 2/5 and keep timeout, capacity, transaction-boundary, or retry
changes separate from the unproven root fix.
