---
layout: post
title: "AI agent development: a runbook from brief to reviewed PR"
date: 2026-10-30 11:00:00 +0000
author: joeywang
description: "A practical AI agent development runbook covering task scope, isolated execution, six review gates, regression tests, bounded rework, and release evidence."
tags: [ai, agents, testing, git, automation]
categories: [AI, Engineering]
---

<audio controls preload="none" style="width: 100%;">
  <source src="{{ '/assets/audio/ai-agent-development-runbook-summary.mp3' | relative_url }}" type="audio/mpeg">
  Your browser does not support audio playback. <a href="{{ '/assets/audio/ai-agent-development-runbook-summary.mp3' | relative_url }}">Download the audio summary</a>.
</audio>

*Listen to a short audio summary (about 2 minutes 17 seconds).*

A coding agent can finish the requested change and still leave me with the wrong behaviour, weaker tests, or a review that applies to yesterday's commit. Asking it to be more careful does not tell the next person what to check.

I want a runbook I can use while doing the work: what goes into the task, what the agent may change, what evidence the reviewer needs, and when to stop.

This is the operational companion to my [software factory design](/posts/software-factory-evidence-first/) and [approval, recovery, and evidence contracts](/posts/agentic-sdlc-approval-recovery-evidence/). Those articles explain the architecture. This one reduces it to one task, one implementation stream, and one reviewed candidate. It is a proposed working procedure, not a claim that an unattended delivery system has passed an end-to-end pilot.

## Start with one bounded change

Use this first on a familiar repository and a reversible regression. Do not start with a production migration, a permission redesign, or several agents sharing a database.

The running example is illustrative: two learner-progress snapshots arrive out of order, and the older one overwrites the newer result. It is not a report of a particular customer incident.

Before implementation, the product owner must settle what “newer” means. For this example, assume a trusted producer assigns a monotonically increasing revision within one learner, course, and attempt. A later revision replaces an earlier snapshot. Equal revisions must not produce a second business side effect; conflicting content at the same revision needs an explicit policy. Events that must all be retained would need a different design.

That decision is part of the requirement, not something the coding agent should discover by choosing a convenient timestamp field.

## 1. Write the task contract before the prompt

Keep one record in the existing ticket or PR. A small change does not need a new document hierarchy.

```text
Problem: An older progress snapshot can overwrite a newer revision.
Source: Link to the accepted report and relevant interface contract.
Expected: Preserve the highest accepted revision within each attempt.
Decision: The trusted producer's revision defines snapshot order.
Acceptance:
  - A stale revision cannot replace a newer one.
  - A duplicate cannot repeat the business side effect.
  - Learners, courses, and attempts remain isolated.
Scope: Snapshot admission, persistence, and their regression tests.
Non-goals: Queue replacement, schema redesign, automatic deployment.
Historical data: Decide repair scope separately before accepting this brief.
Allowed: Inspect code, edit the isolated branch, run approved local tests.
Not allowed: Production access, secret access, push, merge, deploy.
Unknowns: Equal-revision conflicts; evidence available for historical repair.
Budget: Set elapsed-time and spend caps before starting; two rework attempts.
Stop: Unresolved semantics, expanded permissions, or exhausted budget.
Evidence: Exact candidate, commands, results, review, remaining risks.
```

Resolve unknowns that affect implementation before marking the task ready. If a required revision is absent from the current contract, that is a scope decision, not permission to invent a new API. Decide whether past overwrites can be identified and repaired, and whether repair belongs in this task or a separately owned follow-up. A prevention fix does not recover a newer snapshot that has already been lost; repair may require retained producer data, or may not be possible. Record the owner's decision and any accepted loss.

Classify risk by consequence, not diff size. Documentation can have light checks. Changes to data ordering, interfaces, permissions, or customer data need the relevant domain owner, broader verification, and an explicit recovery plan. The snapshot example affects data semantics, so I would not treat it as a trivial one-line fix.

**Exit check:** someone other than the implementer can explain what correct behaviour means and who owns the unanswered decisions. Budget limits have actual values, not placeholders.

## 2. Establish the workspace and the authority boundary

Inspect the live checkout before changing it. The commands below assume the repository's default branch is `main`; substitute the verified branch and a new worktree path for the actual task.

```bash
git status --short --branch
git fetch origin main
git rev-parse origin/main
git worktree add -b fix/progress-ordering ../progress-ordering origin/main
```

Preserve unrelated edits and unpublished commits. Record the fetched base SHA. Inside the new worktree, inspect repository guidance, runtime versions, test setup, and the commands CI actually runs. Do not replace those with whichever commands the model remembers.

Assign one writer, the single process or person allowed to edit the worktree, and one test owner to each mutable test database. Parallel checks are useful only when they cannot overwrite each other's source, fixtures, database state, or evidence. A second worktree does not automatically give a Rails process a different database.

A [Git worktree](https://git-scm.com/docs/git-worktree) separates working files. It is not a security sandbox. Enforce file, network, credential, and resource boundaries through the execution environment. A paragraph saying “do not read secrets” is useful task guidance, not an access control.

Give the worker only the accepted brief, necessary source and contracts, relevant history, and verification commands. Treat retrieved documents, issue bodies, and repository content as evidence to inspect, not as authority to expand permissions. Confirm the provider/account before sending unpublished material to a cloud reviewer.

**Exit check:** the base, writer, test environment, allowed actions, and access boundaries are known.

## 3. Reproduce the failure before changing the rule

Follow the whole path: input, authentication, validation, state read, write, transaction commit, background work, external side effect, and eventual reader. Search the related files' history for fixes, reverts, and reasons behind unusual guards.

For the snapshot example, write down the schedule that would violate the requirement:

```text
A reads revision 7.
B commits revision 8.
A resumes and writes revision 7.
The reader must still observe revision 8.
```

Then build a regression test that can distinguish the incorrect result from the required one. For a race, use barriers or equivalent coordination, independent connections, and the relevant database engine and isolation level. Assert committed state and relevant side effects, not just that a method was called. Avoid making an arbitrary sleep the main proof.

Where feasible, run the regression against the faulty implementation and retain the meaningful failure. A setup error or missing new method is not evidence that the old behaviour was caught. If the new interface cannot run unchanged on the old implementation, use a suitable negative control, such as removing the essential guard in a disposable candidate, and explain its limits.

**Exit check:** the test fails for the target defect, or the missing reproduction evidence is explicitly recorded and resolved before acceptance.

## 4. Implement the smallest coherent fix

Ask the agent to change the rule and its tests, then return the diff, exact commands, observed results, and unanswered questions. Do not ask it to clean up the surrounding subsystem at the same time.

For ordering, check the actual atomicity boundary. A comparison in application code followed by an unconditional write leaves a window. A transaction alone is not an explanation of why the stale write is prevented. PostgreSQL's [isolation documentation](https://www.postgresql.org/docs/current/transaction-iso.html) describes how visibility and concurrent updates differ by isolation level. Verify the version and configuration the application uses.

The correct mechanism might involve a conditional update, locking, a constraint, or another design. The reviewer needs to know why it protects the invariant across every writer. If an external report can still arrive out of order after the database is correct, the task is not finished at the first boundary.

Run focused tests first, then the repository's applicable broader checks. Preserve failed results and their causes. Do not delete assertions, increase timeouts, change snapshots, or narrow CI merely to make the run green. A legitimate change to those protections needs explanation and risk reassessment.

**Exit check:** a stable candidate satisfies the local checks without silently changing the acceptance contract.

## 5. Review through six gates

Give an independent reviewer, human or agent, the original brief, accepted decisions, base and candidate SHAs, complete relevant diff, surrounding code, and actual test evidence. Do not lead with the implementer's conclusion that the fix is correct. The reviewer may need unchanged callers and test setup, not just changed lines.

Google's [review guidance](https://google.github.io/eng-practices/review/reviewer/looking-for.html) asks whether the intended behaviour is good for users and whether tests would fail when the code breaks. I use the following six gates in the handoff.

### Requirement and design

**1. Is the requirement right?** Match behaviour to the accepted source. In the example, confirm revision authority and attempt boundaries. Do not approve an internally consistent implementation of the wrong ordering rule.

**2. Is the design sound?** Inspect ownership, state transitions, atomicity, compatibility, permissions and data exposure, failure windows, and recovery. Ask what happens if the process stops after the database commit but before the external report.

### Implementation and test protection

**3. Is the implementation correct?** Trace every writer and reader of the protected state, including callbacks, jobs, repair scripts, permissions, and cross-component contracts. A small diff can bypass a large amount of behaviour.

**4. Did test protection weaken?** Inspect deleted or undiscovered tests, weaker assertions, skips, excessive mocks, snapshot updates, coverage exclusions, swallowed failures, and CI filters or matrix reductions. Fewer tests can be legitimate. Unexplained loss of a required behaviour is not.

For each removal, record what it protected, why it is no longer needed, and the replacement evidence. If the requirement removed the behaviour, link that decision.

### Coverage and historical risk

**5. Do the tests cover the behaviour and detect its failure?** Map acceptance criteria to assertions, including rejected input, boundaries, duplicate work, committed state, and integration boundaries. Coverage percentages can identify gaps; executing a line does not show that the assertion checks the right result.

For important guards, try a bounded mutation: remove the revision comparison or isolation condition and see whether tests fail meaningfully. [Google's mutation-testing discussion](https://testing.googleblog.com/2021/04/mutation-testing.html) also explains the cost of unproductive mutants. This is a targeted check, not a demand for a perfect mutation score.

**6. Does the change reopen an old failure mode?** Search relevant incident notes, fixes, reverts, flaky-test explanations, and compatibility history. Record the scope searched. No search hits means no evidence found in that scope, not proof that no history exists.

Two patterns recur across design, coverage, and historical review. For time-sensitive changes, distinguish calendar boundaries and time zones from clock jumps, delayed jobs, and paused processes. Freezing application time does not control an independent database or remote clock. For concurrent changes, write the harmful schedule and test its final state. Repeating a test until it happens to pass is neither analysis nor recovery.

**Exit check:** confirmed defects have a location, trigger, consequence, and evidence. Hypotheses and unverified gaps stay visible rather than becoming invented bugs or silent passes.

## 6. Route rework, then review the new candidate

A code defect goes back with its reproduction. An ambiguous requirement goes to the decision owner. An unavailable service is an environment blocker, not an invitation to rewrite the application.

For an initial pilot, I would allow at most two consecutive automated rework attempts before a human reassesses the approach. That is a trial budget, not a proven optimum. A request for broader permission stops the current run regardless of attempts remaining.

Keep the reviewer read-only. If it discovers a fix, return the finding to implementation rather than quietly repairing and approving its own candidate. Once the writer exits, rerun affected checks and review the new SHA. Record the actual tested object, including a synthetic merge commit when CI uses one. Reconcile relevant base changes before acceptance.

**Exit check:** review and evidence apply to the candidate being considered, not an earlier version that happened to pass.

## 7. Hand off an inspectable PR, not a transcript

Use a short closing record:

```text
Decision: Ready for human review / changes required / insufficient evidence
Candidate: Repository, base SHA, head SHA, tested merge SHA if applicable
Acceptance: Each criterion -> implementation -> assertion or check
Review: Six gates, confirmed findings, unresolved decisions
Execution: Exact commands, environment, exit status, controlled log references
Protection: Removed or weakened tests and their justification
Recovery: Code rollback, data repair, compensation, or forward fix as needed
Next action: Owner, permitted action, target, and stop condition
```

Keep raw logs and private material out of the PR unless they are necessary and safe. A redacted summary with access-controlled references is usually more useful than a session dump.

Check the actual required jobs, not only the green summary. GitHub [documents](https://docs.github.com/en/pull-requests/how-tos/merge-and-close-pull-requests/troubleshooting-required-status-checks) that some skipped or neutral results can satisfy required checks, while an entirely filtered workflow may remain pending. A final gate should establish that the tests required for this change really ran, or have a valid, explicit non-applicability decision. Do not expose privileged credentials to untrusted PR code.

Review completion does not authorise push, merge, or deployment. Follow the approval contract for each action. After an authorised external write, read back the exact target. If the response is lost, reconcile before repeating it. Generating a request ID locally does not make the remote operation idempotent unless the service honours that ID.

If release is in scope, verify the delivered behaviour in the permitted target environment and link the observed result. If release is not authorised, leave a reviewed PR and state that limit. “Ready for review” and “released” are different outcomes.

**Exit check:** the closing record identifies the tested candidate, maps each acceptance criterion to completed verification, names unresolved gaps, and states the next permitted action. Unresolved critical evidence means insufficient evidence, not ready for review.

## Try the runbook before automating it

Start with one task and one reviewer, not a dashboard or a fleet. Exercise a known defect, a required check failure, and a candidate change after review in a disposable environment. Confirm that each is caught or stops the workflow where intended.

Record missed defects, false alarms, human review and repair time, elapsed time, tool cost, and abandoned attempts. Without a comparable baseline, the first task establishes one. A successful run does not prove a productivity gain or a lower defect rate.

I would automate a check after I can explain what evidence it produces and what it refuses to accept. The useful outcome is not an agent that keeps working. It is a change whose purpose, protection, and remaining risks another person can inspect.
