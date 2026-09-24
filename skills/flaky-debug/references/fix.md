# Apply a Flaky Test Fix

Apply phase of the flaky-debug skill. Takes a plan produced by the planning phase ([`plan-e2e.md`](./plan-e2e.md) or [`plan-fast-path.md`](./plan-fast-path.md), finished by [`plan.md`](./plan.md)) and applies it.

If `organization-profile.md` exists beside this file, read its **Fix and
handoff additions** before applying the fix. Follow its **Knowledge-base
close-out** pointer after merge; before then, report that duty as pending.

## Preflight

Confirm the plan from `plan.md` has confidence ≥ 3, or that a confidence 1-2
plan was explicitly approved and is limited to diagnostic instrumentation. For
any other confidence 1-2 plan, do not apply -- return to `plan.md` and gather
more evidence first.

Before editing, verify the plan is still current:

- The failing commit's code path still exists on the current default branch, or the plan has been adjusted for the current code.
- No applicable remediation boundary from the
  [systemic-regression contract](./systemic-regression.md) has activated since
  the plan was written. If one has, and every same-mechanism sighting predates
  its evidence-based activation boundary, stop applying and return the plan for
  the post-boundary recurrence check.
- The proposed fix targets the diagnosed failure surface, not only the final assertion.
- The repository and revision named by the plan match the current worktree. If
  the causal owner is another repository or service, stop editing and hand the
  plan to that owner with the target repository, revision, and evidence.
- Any retry/wait change still meets the applicable [fix-approach requirements](./plan.md#decide-fix-approach). Return to the plan when the evidence or safety bounds changed.

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

Run the plan's **Validation plan**, exercising the named failure condition and
its chosen stopping rule. Verification is complete when the specified checks
pass and the outcome is recorded against those criteria. Report commands,
counts, before/after reproduction results when available, and residual
uncertainty. If a check fails or cannot run, record the blocker and revise the
plan before claiming the fix is verified.

## Output Format

Use the [plan output schema](./plan.md#plan-output-format) as the single source
of truth, carrying its investigation and provenance evidence forward. Update
confidence, diagnostic gaps, default-branch status, and residual risk when
verification changes them. Apply these differences:

- **Proposed fix** becomes **Fix**, describing the changes actually made.
- **Validation plan** becomes **Validation**, recording the verification outcomes above.
- **Sibling candidates** retains unmodified candidates; add **Siblings fixed** for confirmed corrections actually made, or `N/A -- fix was test-specific`.
- Add **Handoff** with the target repository/service, revision, owner, and evidence when preflight stopped local editing; otherwise `N/A`.
- Remove **Open questions** once resolved, and add fields or labels required by the organization profile.
