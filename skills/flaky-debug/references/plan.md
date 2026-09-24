# Decide the Fix and Format the Plan

Shared tail of the flaky-debug planning phase, used by both [`plan-e2e.md`](./plan-e2e.md) and [`plan-fast-path.md`](./plan-fast-path.md). Produces a structured plan that the user reviews. In fix mode, the plan is consumed by [`fix.md`](./fix.md).

If `organization-profile.md` exists beside this file, read its **Planning
additions** and **Sibling frontend check** sections before finalizing the plan.

## Confidence Score

Rate your confidence in the root cause on a 1-5 scale. Report this score alongside your evidence.

| Score | Meaning             | Criteria                                                                                                                                                                                                                                                           |
| ----- | ------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| **5** | Certain             | Root cause is directly visible in artifacts AND reproduced by inducing it — fault injection in the harness (delay/fail the blamed response or step) or a focused lower-level test that deterministically reproduces the cause, including the deterministic-boundary equivalence below. Without qualifying reproduction, the ceiling is 4 |
| **4** | High confidence     | The chain terminates at an evidenced cause (file/line, config key, or log line), but reproduction is missing or one intermediate link is inferred rather than observed. An unevidenced terminal cause is a broken chain, capped at 2 (see [Causal Chain](#causal-chain))                       |
| **3** | Moderate confidence | Evidence is consistent with the diagnosis but alternative explanations remain plausible. Flag the alternatives explicitly                                                                                                                                          |
| **2** | Low confidence      | Limited evidence, mostly reasoning from code patterns rather than observed artifacts. Recommend gathering more data before committing to a fix                                                                                                                     |
| **1** | Speculative         | No direct evidence for the root cause. The fix is a best guess. Recommend reproducing the failure locally or adding instrumentation before proceeding                                                                                                              |

**Deterministic-boundary equivalence:** for a pure clock, calendar, configuration,
or literal-threshold defect, a failing artifact plus exact evaluation of the
named code expression at the captured inputs counts as focused lower-level
reproduction. Show the before/after values and why the result is deterministic.
Timestamp correlation or a boundary narrative without that evaluation remains
capped at 4/5.

Apply the score:

- **If >2:** continue to [Decide Fix Approach](#decide-fix-approach).
- **If less than 5/5:** identify the missing evidence and the work that would obtain it. Propose instrumentation for unobserved causal links and a reproduction experiment when reproduction is missing. When artifacts already establish the complete cause, cite them and specify the reproduction gap; additional instrumentation is unnecessary. Scope diagnostic work to the implicated repositories and services, resolving owners from repository metadata, service catalogs, deployment configuration, or the organization profile.
- **If confidence is 2 or below:** do not propose a code fix. Instead, recommend specific instrumentation or reproduction steps to raise confidence.

## Causal Chain

Every plan must trace the failure to a terminal _cause_, not a symptom:

failing assertion → app/UI state → network/trace/log evidence → owning service and repo → cause at a file/line, config key, or specific log line.

- A status code, timeout, or throttle is a link in the chain, never the terminus. "The request 500ed" or "setup was throttled" is where the investigation continues, not where it stops.
- The link types adapt to the failure surface. CI/setup, fixture, component, and unit failures substitute build logs, fixture state, or runner artifacts for network evidence, and the owning package/repo for a deployed service. The invariant is the terminus — a cause, not a symptom — not the specific link types.
- When a network request or deployed service is implicated, resolve its owning service and repository from checked-in ownership metadata, service catalogs, deployment configuration, or the organization profile. Follow the chain into that repository's code — do not stop at the repository containing the test.
- When the causal event may be outside the test's own request path (seeding, deploys, CDC lag, async jobs), trace-ID lookup cannot reach it. Use time-window log queries scoped to the run instead.
- If evidence runs out, state exactly which link breaks and what observability would extend it. That caps confidence at 2, and the instrumentation becomes the deliverable.

## Decide Fix Approach

Applies to all test types.

Choose the fix locus from the evidence, not from where the assertion failed. A flaky E2E test can be exposing a CI dependency issue, auth/test-data service issue, backend bug, deployment problem, product state bug, or test harness bug.

Use this decision order:

1. **Shared setup or CI fix** when many tests fail before user-flow assertions or all failures share a tool, cache, install, auth, seed-data, or fixture path.
2. **Backend/service/data fix** when the expected request is emitted and backend telemetry or response bodies show errors, throttling, stale data, inconsistent state, or unexpected latency.
3. **Product fix** when real users can hit the same unsafe intermediate state, render error, permission/session race, stale cache, or missing error handling.
4. **Test data or harness fix** when the scenario is not user-realistic, the test setup is semantically wrong, or the test needs a deterministic app-ready signal.
5. **Assertion/locator fix** only when the app state is correct and the selector/assertion is the only broken part.

Before proposing a retry, timeout, or wait change, establish these requirements:

- Repeated operations are idempotent and preserve the same test scenario.
- Retry predicates identify the exact transient signatures they accept; validation failures remain terminal.
- Retries have finite attempt or total-call bounds. Exhaustion reports the attempts and last stdout/stderr/status/body.
- Quota-limited dependencies have a concurrency or call-volume bound that controls amplification. Serialize or cache when necessary; a cap does not make a non-idempotent operation safe.
- Waits use a deterministic readiness signal when available. A longer timeout needs evidence that the expected operation is healthy and its duration exceeds the existing budget.

Apply retry requirements only when an operation is repeated; mark inapplicable
checks with a reason. If an applicable requirement lacks evidence, propose a
root-cause fix or diagnostic work to establish it before adding the retry/wait.

Common valid fix types:

- **Shared setup / CI**
  - Pin or lock runtime tools and dependencies
  - Fail fast on incompatible tool contracts
  - Remove mutable global state from CI setup
  - Add setup-level diagnostics before sharding

- **Test harness / data** (when the failure is non-product):
  - Reset cookies, storage, and session between retries
  - Isolate test data; generate stronger unique identities
  - Make retry blocks idempotent
  - Wait on deterministic app signals, not arbitrary sleeps
  - (Service tests) Close connections and app properly in `afterAll`
  - (Component tests) Flush pending state updates and timers before asserting
  - (Unit tests) Reset shared mutable state in `beforeEach`

- **Product** (when real users would hit the same issue):
  - Handle stale or intermediate states safely
  - Make routing/render logic robust to eventual consistency
  - Add telemetry for ambiguous transitions

- **Backend/service**
  - Remove avoidable shared mutable writes from hot paths
  - Make setup operations idempotent or explicitly rate limited
  - Fix stale reads, cache invalidation, and eventual-consistency assumptions
  - Add trace/log correlation for ambiguous failures

Choose **both** if user impact exists _and_ tests are fragile.

## Plan Output Format

Produce the plan with these fields:

- **Test ID:** if provided in prompt
- **Investigation reference:** a resumable session ID when the agent exposes one;
  otherwise the durable report, ticket, or run identifier. Never invent a session ID.
- **Confidence:** score (1-5) with brief justification
- **Failure surface:** CI/job setup, test setup/auth/data, app bootstrap, user action no-op, backend request, post-success render, assertion/locator, or mixed
- **Current default-branch status:** whether the failing commit's code path still exists on the current default branch, has already been fixed, or has changed enough that the plan must be adjusted
- **Prior attempts:** carry the complete Phase 1b table, including each attempt's disposition and supporting evidence. If none exist, include `None found` and the searches run.
- **Runtime provenance:** when a prior fix or current failure implicates a deployed service, record the observed environment, runtime version or source revision, linked fix revision, deployment evidence, and ancestry result. Do not use merge time as proof that a fix was running.
- **Symptom:** what failed and where
- **Why / customer impact:** why this flake needs to be fixed and how the underlying failure or test unreliability could affect customers. Distinguish direct customer impact from indirect reliability, operational, or developer impact; do not fabricate impact.
- **Root cause:** concise technical explanation
- **Causal chain:** each link from failing assertion to terminal cause with its evidence, or the explicit break point and the observability that would extend it (see [Causal Chain](#causal-chain))
- **Evidence:** artifacts supporting the diagnosis (traces, network, error messages, screenshots as applicable)
- **Proposed fix:** fix locus and scope — shared setup/CI, backend/service/data, product, test data/harness, assertion/locator, or multiple layers — with the specific file(s) and the change you would make
- **Observability to reach 5/5:** identify unobserved links and the diagnostic work needed to expose them. When the cause is fully observed, cite the existing evidence and state `No instrumentation gap`. Separately identify missing reproduction and the experiment that would establish it. Use `N/A -- confidence is 5/5` when both are complete.
- **Sibling candidates:** files that appear to share the same anti-pattern, for the reviewer (or fix.md) to confirm. Or "N/A -- fix is test-specific" if the issue is one-off (see [`fix.md`](./fix.md) for what counts as a structural anti-pattern worth searching for).
- **Validation plan:** the failure-provoking condition, how validation exercises it, commands for the affected test and focused reproduction, and a run count or bounded stopping rule chosen before verification. Prefer a deterministic reproduction that fails before the fix and passes afterward. When reproduction is unavailable, justify the bounded repeat strategy and state the remaining uncertainty. Include relevant lint/typecheck commands.
- **Open questions:** anything that needs human input before fixing
- **Residual risk:** what could still be flaky after the fix
