---
layout: post
title: "From machine code to LLMs: preserving intent in tasks"
date: 2026-10-06
author: "Joey Wang"
description: "LLMs make instructions easier to write, but intent still gets lost; a practical task contract makes context, permissions, and completion explicit."
categories: [AI, Engineering]
tags: [ai, llm, agents, testing, productivity]
---

"Make this better" is an easy instruction to type. It is also an expensive instruction to misunderstand.

For a blog post, better might mean shorter, more technical, or easier for a customer to understand. For an application, it might mean faster responses, fewer failures, or a cleaner interface. An LLM can produce a convincing result for any of those interpretations. Only some will match what we wanted.

I keep coming back to the history of programming languages. We made computers easier to instruct by moving away from machine-level details. LLMs take that further: we can describe a goal in ordinary language and let a system work out some of the implementation. But the distance between what we mean and what gets done has not disappeared.

My proposal is to treat an important LLM request as a small task contract. Use conversation to discover the task, then record the decisions that matter and check the result against them.

## What changed between machine code and natural language

The familiar story goes from binary instructions to assembly, higher-level languages such as C, and eventually natural-language interfaces. That is a useful sketch of increasing abstraction, not a complete history or a claim that one replaced the others. LLM-powered software still depends on conventional code underneath.

Each interface asks the human to supply a different kind of precision. In C, I have to express operations through defined syntax and language semantics. A compiler can reject malformed syntax. It cannot tell me that a syntactically valid program solves the wrong customer problem.

With an LLM, I can leave more implementation choices open. That is useful when I want suggestions, a first draft, or help exploring a problem. The difficulty is deciding which choices I meant to delegate and which I merely forgot to specify.

"Improve the signup flow" leaves room for design judgment. It may also leave unanswered whether the agent can change authentication, introduce a new dependency, or deploy the result. Those are different kinds of uncertainty. I want creative freedom on the interface without accidentally granting freedom over production.

Natural language gives us a more forgiving input interface. It does not give us compiler-like guarantees about the meaning of the output.

## Where intent gets lost

I would separate several failures that often get described as "the AI misunderstood me."

Sometimes information was never transmitted. The user knows that "the report" means the monthly customer report, but the model has no reliable way to identify it. Sometimes the words support several meanings: "active user" could mean someone who logged in, paid, or completed a lesson. Sometimes the instructions conflict: "keep it brief" competes with "explain every exception."

Context can also be present without being used effectively. *Lost in the Middle* found that the models studied performed differently depending on where relevant information appeared in long inputs, with weaker performance when it was in the middle.[2] That is evidence from particular models and tasks, not a universal law for every current model. It is still a reason to test whether our system uses the context we give it, rather than equating a large context window with reliable understanding.

The last failure is verification. An agent may understand the request and still implement it incorrectly. A polished completion message can hide that distinction if nobody checks the artifact.

These problems need different remedies. Missing business definitions need clarification. Conflicting requirements need priorities. Implementation errors need tests. Rephrasing the prompt cannot fix a missing permission or an inaccessible database.

A 2025 study, *What Prompts Don't Say*, examined underspecification across three representative tasks and found that relying on models to fill in omitted requirements was fragile across prompt and model changes.[1] The same study found that explicitly listing every requirement did not consistently improve performance, partly because requirements could conflict and models struggled to follow many at once.[1]

That complicates the advice to "just be more specific." Specific about what, and at what cost?

## A task contract that fits on one screen

For consequential work, I would start with these fields:

```text
Outcome:
  What should be different when the task is finished?

Context and sources:
  Which files, documents, examples, or definitions matter?
  Which source wins if they disagree?

Scope:
  What is included? What is explicitly excluded?

Constraints and permissions:
  What must remain true? What may the agent change?
  Which actions require approval?

Acceptance checks:
  What observable evidence would show that the task succeeded?

Uncertainty:
  What should the agent ask about, and what may it assume?

Deliverable:
  What artifact should it return, and where should it go?
```

This is a proposed working format, not a new standard or a proven optimal prompt. Markdown is enough. The labels matter less than whether the answers rule out the costly wrong interpretations.

The outcome should describe a result rather than a vague activity. "Investigate performance" names an activity. "Identify the cause of slow report generation and propose a fix without changing production" gives the investigation a boundary.

Acceptance checks should describe observable behavior. "High-quality code" tells the agent little. "Include a regression test for the reported failure and run the relevant test suite" gives both parties something to inspect. Tests still need judgment: a passing test for the wrong requirement proves very little.

Permissions deserve their own line. Read access, local edits, opening a pull request, merging, deployment, spending money, and contacting customers are separate capabilities. A written boundary communicates intent; tool permissions and approval gates must enforce it. A prompt is not an access-control system.

## Turning a vague request into a bounded task

Consider an illustrative request to a coding agent:

> Fix duplicate welcome emails.

The request names a symptom, but it leaves important decisions open. A more useful handoff might look like this:

```text
Outcome:
  Retrying the same welcome-email job must not deliver a second
  welcome email for the same signup.

Context:
  Inspect the job implementation and its tests first.
  The scope is duplicate delivery caused by retries of that job.

Scope:
  Change the welcome-email path and directly related tests only.
  Do not redesign signup or change other notification behavior.

Constraints and permissions:
  Work on an isolated branch. Do not access production or deploy.
  Ask before adding a dependency or database migration.

Acceptance checks:
  Add a regression test reproducing the retry behavior.
  Show that it fails before the fix and passes afterward.
  Run the relevant existing tests and report their actual results.

Uncertainty:
  If preventing duplicates would suppress legitimate delivery,
  explain the trade-off before choosing an approach.
  If the cause lies outside this job, report the evidence and
  ask before expanding scope.

Deliverable:
  Return the patch, verification evidence, and remaining risks.
```

This is a hypothetical example, not a report of a completed fix. It does not prescribe a particular implementation, because the right implementation depends on the delivery system and its failure modes. It specifies the problem tightly enough that an agent cannot reasonably substitute a broad cleanup or silently claim to have eliminated every possible duplicate.

It also exposes a product decision: under some failure conditions, preventing duplicates may increase the risk of a missed email. That trade-off belongs in the conversation before it becomes an accidental implementation choice.

## Use conversation to discover, then freeze the decision

A task contract does not have to arrive fully formed. Often I need the LLM to help identify what is missing.

A useful first step is:

> Before making changes, state the intended outcome, identify ambiguities that would materially change the work, and tell me what evidence you will use to verify completion.

The response should be a short interpretation of the task, not a request for hidden internal reasoning. If the agent says it plans to rewrite the notification system, the mismatch is visible before it changes anything.

Clarifying everything would make the interface miserable. The decision rule I would use is to ask when the answer changes correctness, scope, risk, or an expensive commitment. For reversible presentation choices, proceed with a stated assumption. Choosing a heading style is different from choosing which customer records to delete.

After clarification, update the contract. Do not leave the final decision buried among discarded options in the chat. Give it a revision identifier if the work spans sessions or multiple agents. A later correction should explicitly supersede the earlier requirement.

For a handoff, preserve the current outcome, constraints, decisions, artifact locations, completed checks, and unresolved questions. "Continue what we discussed" is a poor substitute for a readable task state.

## More structure helps with shape, not truth

If software needs to consume the result, a schema is useful. For example, a task report could require fields for status, artifacts, checks, and unresolved questions. OpenAI's Structured Outputs documentation describes constraining supported model responses to a supplied JSON Schema.[3]

The same documentation cautions that structured outputs can still contain mistakes.[3] A valid field saying `"tests_passed": true` does not prove that tests ran. The application needs to examine actual test results, handle refusals or incomplete responses, and validate values that matter.

I would use prose for goals and trade-offs, structured fields for machine processing, executable checks for behavior, and enforced permissions for actions. Putting everything in JSON would make some requests harder to write without settling their ambiguity.

For a casual question, all of this is unnecessary. For an agent that can edit a repository or change an external system, the extra structure is worth considering.

## Efficient communication means less rework

The shortest prompt is not necessarily the cheapest workflow. It may save a little typing and create a large review burden.

I would measure a task format by whether it helps produce an acceptable artifact with fewer corrections. For repeated workflows, keep a small collection of representative tasks, including ambiguous inputs and boundary cases. Compare versions of the instructions against the same checks. Recheck them when the model or agent tooling changes, because a format that worked once is not a permanent guarantee.

Some repetition is useful. Carrying "do not deploy" into a handoff preserves a boundary that matters. Repeating every log line and abandoned idea adds reading cost without necessarily preserving intent. Keep the authoritative documents and raw evidence accessible, while putting the current task and its important constraints in a compact brief.

This follows the blog's earlier discussion of [the developer's changing role](/posts/ai-era-developer-role-coder-to-architect/), but makes the handoff more concrete. Deciding what a system should do includes deciding how another system will recognize that it has done it.

I do not want us to recreate C syntax in English. The freedom to describe an outcome is the useful part of working with LLMs. I want to preserve that freedom while making definitions, permissions, and completion checks explicit wherever misunderstanding would be costly.

Start with an ordinary request. Before handing over consequential work, write down what must survive the conversation and how you will check it afterward.

## Sources

[1] https://arxiv.org/html/2505.13360v2
[2] https://arxiv.org/abs/2307.03172
[3] https://platform.openai.com/docs/guides/structured-outputs
