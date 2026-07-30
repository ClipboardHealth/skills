# Apply a Flaky Test Fix

Apply phase of the flaky-debug skill. Takes a plan produced by the planning phase ([`plan-e2e.md`](./plan-e2e.md) or [`plan-fast-path.md`](./plan-fast-path.md), finished by [`plan.md`](./plan.md)) and applies it.

If `organization-profile.md` exists beside this file, read its **Fix and
handoff additions** and **Knowledge-base close-out** sections before applying
the fix or declaring the workflow complete.

## Preflight

Confirm the plan from `plan.md` has confidence ≥ 3, or that a confidence 1-2
plan was explicitly approved and is limited to diagnostic instrumentation. For
any other confidence 1-2 plan, do not apply -- return to `plan.md` and gather
more evidence first.

Before editing, verify the plan is still current:

- The failing commit's code path still exists on the current default branch, or the plan has been adjusted for the current code.
- The proposed fix targets the diagnosed failure surface, not only the final assertion.
- The repository and revision named by the plan match the current worktree. If
  the causal owner is another repository or service, stop editing and hand the
  plan to that owner with the target repository, revision, and evidence.
- Any retry/wait change is safe and idempotent; it must not repeat one-time credentials, duplicate writes, or destructive actions.
- The retry predicate names the exact transient failure signatures it matches: opaque 5xx yes; 4xx validation no; 429 only with a cap.
- The retry has a finite attempt or total-call bound, and exhaustion reports the attempts plus the last stdout/stderr/status/body.
- A retry against a rate-limited or quota-limited dependency such as an identity provider, a 429-emitting API, token minting, one-time credential provisioning, or seed creation states its concurrency cap or call-volume bound. Without one, return to the plan and serialize or cache the operation. A cap does not make a non-idempotent operation safe.

## Apply the Proposed Fix

Edit the files listed in the plan's **Proposed fix** field. Keep the change
minimal -- the plan identifies the fix locus: shared setup/CI,
backend/service/data, product, test data/harness, assertion/locator, or multiple
layers.

Do not convert an infrastructure, backend, auth/data, or product-state root cause into a frontend timeout or locator retry. If the plan's evidence no longer supports the proposed fix, stop and revise the plan.

## Fix Sibling Instances

After fixing the root cause, search for other tests that exhibit the same anti-pattern. Flaky patterns often have siblings nearby, but do not turn a one-test plan into broad repo churn.

### When to search

Search for siblings when the root cause is a **structural anti-pattern** -- something that would be wrong regardless of the specific test logic:

- Missing or incomplete teardown (`afterAll`/`afterEach` not closing connections, not restoring mocks)
- Hardcoded ports instead of dynamic allocation
- Shared mutable state without per-test reset
- Missing `act()` wrappers or `waitFor` around async assertions
- Fake timers not restored in `afterEach`
- Stale data patterns (E2E: missing reload/re-fetch; service: no DB cleanup between tests)

### When NOT to search

Skip this step when the fix is **specific to one test's logic** -- for example a test-specific race condition in a unique setup or a one-off typo.

### How to search

1. Identify the anti-pattern as a grep-able code pattern. Examples:
   - Missing connection cleanup: grep for `createTestingModule` in test files and check each for proper `afterAll` teardown
   - Hardcoded port: grep for `listen(3000)` or `listen(PORT)` in test files
   - Missing mock restore: grep for `jest.spyOn` in files that lack `restoreAllMocks`
   - Missing `act()`: grep for `render(` in `.test.tsx` files that call state-changing functions without `act` or `waitFor`

2. Scope the search to the same area of the codebase first (same package or directory), then widen if the pattern is pervasive.

3. Apply the same fix to each sibling named in the plan or directly confirmed as the same root cause. Keep changes minimal; fix the anti-pattern, nothing else. Report broader candidates instead of editing them unless they clearly share the root cause.

4. List the sibling files you fixed in the output so reviewers can verify them.

## Verification

Run the plan's **Validation plan** commands — including the previously-flaky test, repeated enough times to give reasonable confidence the flake is gone. Lint and type-check touched files as the floor; do not stop there.

## Output Format

When documenting the fix in a PR or issue, use this structure. Carry the
investigation and provenance fields straight over from the plan. Two plan fields
rename: **Proposed fix** → **Fix** and **Validation plan** → **Validation**.
**Siblings fixed** lists only corrections actually made; keep unmodified
**Sibling candidates** separate. Drop **Open questions** after resolving them.
Add any fields and labels required by the organization profile.

- **Test ID:** if provided in prompt
- **Agent session ID:** your running session ID to resume if needed
- **Confidence:** score (1-5) with brief justification
- **Failure surface:** where the failure first surfaced and why the fix belongs there
- **Current default-branch status:** whether the failure path still existed when the fix was made
- **Prior attempts:** carry the plan's complete prior-attempt table and recurrence evidence
- **Runtime provenance:** observed environment and revision, linked fix revision, deployment evidence, and ancestry result
- **Symptom:** what failed and where
- **Why / customer impact:** carry unchanged from the plan
- **Root cause:** concise technical explanation
- **Causal chain:** each evidenced link to the terminal cause
- **Evidence:** artifacts supporting the diagnosis (traces, network, error messages, screenshots as applicable)
- **Observability to reach 5/5:** carry the remaining diagnostic work, or `N/A -- confidence is 5/5`
- **Fix:** fix locus and scope: shared setup/CI, backend/service/data, product, test data/harness, assertion/locator, or multiple layers
- **Handoff:** target repository/service, revision, owner, and evidence when preflight stopped local editing; otherwise `N/A`
- **Sibling candidates:** candidates identified by the plan but not modified
- **Siblings fixed:** files where the same anti-pattern was actually corrected (or "N/A -- fix was test-specific")
- **Validation:** commands and suites run
- **Residual risk:** what could still be flaky
