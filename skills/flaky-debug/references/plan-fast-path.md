# Plan a Flaky Test Fix -- Fast Path (Service, Component, Unit)

Diagnosis and planning phase of the flaky-debug skill for service, React component, and unit tests. Produces a structured plan that the user reviews. Ends at [`plan.md`](./plan.md) for the fix decision and plan output format.

Begin this fast path only after completing every mandatory dossier and
current-code check in `SKILL.md` Phase 1b, including prior-fix searches,
current-default-branch verification, and recurrence analysis. When the evidence
implicates an external service or another repository, switch to the shared
[Causal Chain](./plan.md#causal-chain) investigation with runner, service, and
dependency evidence, then complete `plan.md`. Otherwise, the failure information
plus the test source is usually sufficient: read the evidence, read the code,
and plan the fix.

## Gather Failure Context

Capture from the user's input (ask if missing):

- **Test file and name** -- exact file path and test title
- **Error message and stack trace** -- the raw failure output
- **Framework** -- Jest, Vitest, etc.
- **Failure metadata** -- branch, pipeline URL, duration, shard, timestamp (when available)

## Read the Test and Code Under Test

1. Read the failing test file. Focus on the specific failing test and its surrounding `describe`/`beforeEach`/`afterEach`/`afterAll` blocks.
2. Read the production code that the test exercises -- follow imports from the test file.
3. For service tests: also read the test module setup (the `Test.createTestingModule(...)` or app bootstrap code), and check for `afterAll` cleanup that closes the app/database connections.

## Classify the Flake Pattern

| Category                        | Test Types      | Signal                                                                                                             |
| ------------------------------- | --------------- | ------------------------------------------------------------------------------------------------------------------ |
| **Connection lifecycle**        | Service         | "connection closed", "topology destroyed", socket errors in stack -- app/DB not fully ready or torn down too early |
| **Port conflict**               | Service         | EADDRINUSE -- multiple test files bootstrapping on the same port                                                   |
| **Async teardown race**         | Service         | Errors appear after test passes -- `afterAll` closes the app while background work is still running                |
| **Database state leakage**      | Service         | Test depends on DB state that a parallel/prior test modified                                                       |
| **Unresolved async work**       | Component       | "not wrapped in act()" warnings, state updates after unmount                                                       |
| **Timer/animation not flushed** | Component       | Test asserts before `setTimeout`/`requestAnimationFrame` fires, or `useFakeTimers` not advanced                    |
| **Mock not restored**           | Component, Unit | `jest.spyOn` or `jest.mock` bleeds into the next test -- missing `mockRestore`/`restoreAllMocks`                   |
| **Shared mutable state**        | Unit            | Module-level variable or singleton mutated by one test, observed by another                                        |
| **Date/time sensitivity**       | Unit            | Test assumes a specific date, time zone, or `Date.now()` value that shifts across runs                             |
| **Test ordering dependency**    | All             | Passes in isolation, fails when run with other tests (or vice versa)                                               |

## Diagnose with Evidence

Before proposing a fix, gather:

- The **error message and stack trace** from the failure
- The **specific code path** in the test or production code that caused the flake
- A brief **explanation** of why the flake is intermittent (what timing or state condition triggers it)
- A **confidence score** -- see [Confidence Score](./plan.md#confidence-score) in `plan.md` for the 1-5 scale and what to do with it.
