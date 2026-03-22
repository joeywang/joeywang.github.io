---
layout: post
title: "What Subagents Are Actually Good For in Codex"
date: 2026-03-16
description: "A field guide for AI-heavy early adopters on when subagents in Codex speed work up, when they slow it down, and how to use them without creating chaos."
tags: [ai, codex, agents, engineering, productivity, code-review]
categories: [ai, engineering]
---

## What Subagents Are Actually Good For in Codex

I did not start out as a subagent enthusiast.

My first reaction was basically the same one I have to most new AI workflow ideas: this sounds nice in a demo, but I do not want to turn a straightforward coding session into project management theater. If using subagents just means opening more threads, repeating context, and cleaning up conflicting edits, then the whole thing is worse than useless.

After using Codex on real repositories for a while, my view changed, but only in a narrower way than the marketing version. I do not think subagents are a magic productivity multiplier. I do think they are genuinely useful when you use them for the kind of work that benefits from parallel implementation and parallel review, and when the main agent stays firmly in charge.

That distinction matters.

The best results I have had with subagents did not come from telling three agents to "go fix the bug." They came from treating the parent agent like a tech lead for a small, temporary team. The parent agent decomposes the work, assigns clear ownership, waits for bounded results, integrates the pieces, and runs final verification. The subagents do not replace that judgment. They only make it possible to run more than one useful thing at once.

That is the real value, at least for me. Not autonomous software development. Not "AI employees." Just less idle time while one thread is waiting for another.

## The moment it started feeling useful

The workflow clicked for me when I stopped using subagents for vague exploration and started using them for implementation and review in parallel.

There is a common bottleneck in normal coding work. You are changing one area of the codebase, but you also need someone, or something, to do one of these in parallel:

- check whether your patch creates risk somewhere adjacent
- review a narrowly scoped change for correctness
- add or extend a regression test in a related but separate area
- draft the docs or migration notes while implementation is still moving

If I do all of that serially in one context, it works, but it is slow. I implement, then switch mental gears, then review my own patch, then chase collateral issues, then go write documentation after I am already tired of the topic. Nothing is impossible there. It is just inefficient.

With subagents, that can become:

1. The parent agent decomposes the task.
2. One subagent implements a bounded slice.
3. Another subagent reviews a different bounded slice, or audits likely fallout.
4. The parent agent compares outputs, resolves conflicts, and verifies the integrated result.

That is not glamorous. It is just useful.

The first time I saw this work well, the interesting part was not raw speed. It was the drop in dead time. While one subagent was writing a focused patch, another was already pressure-testing assumptions around it. By the time I got back to integration, I was not looking at a single proposed change. I was looking at a change plus an early review pass. That is a much better place to make decisions from.

## The mental model that keeps this from turning into chaos

The easiest way to misuse subagents is to think of them as extra hands you can throw at any problem. That framing leads straight to duplicate work, merge conflicts, and fake progress.

The model that holds up better is simpler: a subagent is good at bounded work with a clear stop condition.

That usually means the task is:

- easy to describe in one message
- low-coupling relative to the rest of the task
- independently verifiable
- narrow enough that success or failure is obvious

If I cannot describe the task cleanly in one paragraph, I probably should not delegate it yet. If I cannot explain how I would verify the output without rereading half the repository, I probably should not delegate it. If two subagents would need to keep checking each other's reasoning every few minutes, I definitely should not delegate it.

This is why subagents work better as force multipliers for already-understood work than as replacements for active exploration.

When I am still figuring out the shape of a problem, I usually stay local. The next step depends too heavily on what I just learned. The task boundaries are still moving. That is a bad time to fan out work.

Once the boundaries are clear, delegation gets much easier.

## Where subagents really help

For me, the highest-leverage use case is not "parallelize everything." It is parallelize the parts that benefit from having different kinds of attention.

Implementation and review are a good example because they are related, but not identical. One thread is trying to make the change. The other is trying to poke holes in it, check edge cases, or look for nearby fallout. Those are complementary tasks. They are not the same task done twice.

Here is the kind of split that tends to work well:

- Subagent A owns a focused patch in one file family or subsystem.
- Subagent B reviews a nearby surface for regressions, or checks related flows that the patch might affect.
- The parent agent stays responsible for any shared files, synthesis, and final verification.

The review subagent does not need to be a human imitation of a senior engineer delivering abstract feedback. It just needs a bounded question. For example:

- does this patch break the same behavior on mobile and desktop
- are there tests covering the failure mode that triggered this work
- what shared helpers or config paths are likely to be touched indirectly
- does a similar code path elsewhere have the same bug

That is where the workflow starts to feel better than simple speedup. You get implementation movement and skepticism at the same time.

That combination is rare in ordinary solo work. Most of us are not at our most critical while actively writing the patch.

## The parent agent still has to do the hard part

This is the part people skip when they get excited about delegation.

Subagents do not remove the need for ownership. They make ownership more important.

The parent agent still needs to own:

- the overall goal
- the decomposition
- the boundaries between tasks
- the merge decisions
- the final test run
- the judgment call on whether the work is actually done

If that sounds obvious, good. It should. But in practice this is exactly where bad subagent sessions go off the rails. The parent agent gets lazy, delegates a fuzzy problem, and then acts surprised when the outputs overlap or contradict each other.

I have learned to be much stricter here. If a task is still fuzzy, I do not delegate the fuzziness. I resolve the fuzziness first.

That often means the parent agent does the first pass locally, figures out the dependency graph, identifies which files are likely shared, and only then spins out bounded subtasks. In other words, the main agent does the thinking that creates clean interfaces. The subagents benefit from that clarity.

Without that step, you are not parallelizing work. You are parallelizing confusion.

## Good delegation prompts are boring on purpose

The prompts that work best are not clever. They are explicit.

I want five things in a delegation prompt:

- the scope
- the files or subsystem to inspect
- the output I expect back
- how to verify it
- what not to touch

The difference between a good prompt and a bad one is usually whether the subagent knows where to stop.

Bad:

> Fix the UI bug.

Better:

> Inspect the lesson runtime input flow and add a regression test for focus-driven pagination. Limit changes to the input and form behavior tests. Return a short summary of what changed and what you ran to verify it. Do not touch shared helpers.

That second version is not elegant prose, but it gives the subagent a boundary, an output format, and a stop condition. That is enough.

In practice, I have found that most subagent failures are not model failures. They are task-shaping failures. The prompt was too broad. Ownership was unclear. The stop condition was missing. Two agents were effectively told to roam in the same area and "help."

That is not a delegation problem. That is a management problem.

## The best boundaries are smaller than you think

The temptation is to split work by feature, but that is often too broad. Better boundaries are usually more mechanical than that.

The cleanest subagent boundaries I have seen tend to be one of these:

- one file family
- one test suite
- one doc artifact
- one investigation path
- one review pass

That sounds almost boringly narrow, but narrow is what keeps the work composable.

If two agents need to touch the same file at the same time, I start looking for a different split. Sometimes the answer is to split by phase instead of ownership: one agent investigates, one writes tests, the parent agent applies the final patch. Sometimes the answer is even simpler: do not parallelize this part.

That last option matters more than people like to admit. Not every task gets better when you add concurrency. Sometimes you just add bookkeeping.

## Where subagents make things worse

I like subagents more now than I used to, but I trust them less in a few specific situations.

I avoid delegation when the task is still being discovered. I avoid it when behavior spans several files in one tight flow and I need one continuous reasoning thread. I avoid it when the change is small enough that briefing the subagent would take longer than doing the work. And I especially avoid it when multiple edits must land in the same file.

The failure modes are pretty consistent:

### Overlapping ownership

Two subagents edit the same file, or solve the same bug from different directions. Now you have collisions plus duplicated reasoning.

### Hidden dependencies

Two tasks look separate, but they both depend on the same helper, config, or shared contract. One subagent "finishes" work that becomes invalid the moment the other one lands.

### Narrow verification

The patch looks plausible, but nobody actually checked the user-visible behavior that broke in the first place.

### False confidence

This one is subtle. A subagent successfully fixes one symptom, and the session starts to feel productive, so everyone moves on before checking whether the underlying contract mismatch is still there.

### Too much parallelism

This is the most predictable mistake. Once delegation is available, every task starts to look parallelizable. It is not. More subagents do not automatically mean more throughput. At some point you are just paying coordination tax.

That last one matters. The parent agent has finite attention. If integration and verification become the new bottleneck, adding more subagents does not help.

## Verification has to be built into the task

One thing I like about this workflow is that it forces a more disciplined definition of done.

A subagent task is not complete because it produced text or code. It is complete when it returns something I can evaluate with confidence.

For implementation work, I want the subagent to answer:

- what changed
- what it ran to verify the change
- what was failing before
- what still remains untested

For investigation work, I want:

- which files matter
- what the likely root cause is
- what evidence supports that claim
- what the smallest safe fix looks like

For review work, I want:

- what risk the reviewer checked for
- what it found
- what still looks ambiguous

This sounds procedural, but it saves time because it keeps local confidence separate from system confidence.

A subagent can tell me, with decent credibility, that a focused patch looks good and passes the relevant tests. The parent agent still needs to decide whether the repository as a whole is in a good state. Those are different questions, and I do not want to blur them.

## The workflow I keep coming back to

The pattern I trust most now looks like this:

1. I keep the parent agent local until I understand the shape of the task.
2. I map the dependencies and decide what can actually move in parallel.
3. I delegate only bounded slices with clear ownership.
4. I try to pair implementation with review, not just implementation with more implementation.
5. I keep shared files parent-owned whenever possible.
6. I integrate the least risky results first.
7. I rerun verification after integration, not before.

This is not fancy, and that is part of why it works.

The workflow also scales down well. You do not need a swarm. In many cases, one subagent implementing a focused slice while another reviews or audits fallout is enough to make the session noticeably better.

That is probably the main point I would make to anyone evaluating whether subagents are worth it. The value is not in spawning as many workers as possible. The value is in choosing one or two places where parallel attention helps more than it hurts.

## So, are subagents worth it?

For AI-heavy early adopters, yes, but only if you are willing to be strict about task shape.

If your goal is to hand a messy problem to several agents and hope the right answer emerges, I think you will be disappointed. The output may look busy. That is not the same as being good.

If your goal is to take work that is already decomposed, hand off bounded slices, and get implementation plus review moving at the same time, then yes, subagents are worth it. That is where they feel less like a novelty and more like a real improvement to the workflow.

My own rule now is simple: if I can describe the task clearly, verify the output independently, and keep ownership boundaries clean, I will consider a subagent. If not, I stay local until I can.

That rule has saved me from a lot of unnecessary chaos.

And honestly, that is the most useful thing I can say about subagents in Codex. They are not interesting because they let you do everything in parallel. They are interesting because they force you to get honest about which parts of the work were actually separable in the first place.
