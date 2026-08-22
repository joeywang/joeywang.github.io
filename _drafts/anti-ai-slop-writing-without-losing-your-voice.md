---
layout: post
title: "How I Use Anti-Slop Editing Without Flattening My Voice"
date: 2026-08-22
author: "Joey Wang"
description: "A practical writing workflow for using anti-AI-slop skills on technical blog posts without sacrificing evidence, personality, or engineering judgment."
tags: [ai, writing, ai-agents, software-engineering]
categories: [AI, Writing]
---

# How I use anti-slop editing without flattening my voice

A post by [@shao__meng](https://x.com/shao__meng/status/2091003945737236959) collected ten skills designed to remove the familiar fingerprints of AI-written prose. The list includes `stop-slop`, `no-ai-slop`, `humanizer`, `unslop`, `slopbeth`, `deslop`, and several other variations.

The visual comparison is useful. It also raises a problem: if I install every anti-slop skill and run them one after another, I may end up with writing that has fewer obvious AI habits but no longer sounds like me.

That would be a bad trade.

I write about Rails, infrastructure, AI systems, security, and the small failures that appear when software meets real users. The point of the blog is not to produce text that passes a detector. The point is to show how I think, what I actually tested, and where my conclusions are still uncertain.

## The problem with one giant rewrite prompt

A generic instruction such as "make this sound human" hides several different jobs:

- checking whether the technical claims are true;
- removing repeated structure and empty transitions;
- improving the order of the argument;
- preserving the author's experience and opinions;
- tightening sentences that say less than they appear to say.

Those jobs need different kinds of attention. A prose cleanup cannot verify a Kubernetes command. A fact check should not erase a first-person account because it sounds less polished than documentation. A structural edit should not turn every article into the same sequence of introduction, three benefits, challenges, and conclusion.

I get better results when I separate the passes.

## The workflow I want for my blog

### 1. Start with evidence

Before polishing the prose, I list the claims that matter:

- What did I observe directly?
- Which commands, logs, or source documents support it?
- Which parts are my interpretation?
- Which parts came from somebody else's post or documentation?
- What remains untested?

This is especially important for articles about security incidents, vendor behavior, benchmarks, and production operations. Smooth prose can make a weak claim look established. That is exactly backwards.

### 2. Keep the rough human material

My useful material is often not elegant. It includes the moment a deployment failed, the misleading error message, the command I almost ran, or the trade-off I still dislike.

Those details carry more credibility than a paragraph about "the rapidly evolving landscape of AI." I would rather keep a slightly awkward sentence that records a real decision than replace it with a polished sentence that could have been written about any project.

### 3. Edit the structure

The next pass asks whether the article has a reason to exist. Does it explain a failure, a decision, a technique, or a pattern that another engineer can use?

I cut sections that only announce what the article is about. I remove headings that repeat the paragraph underneath. I move background below the concrete problem when the reader needs the problem first.

This is where an anti-slop skill is useful, but it should make the article more direct rather than more uniform.

### 4. Remove the statistical habits

The familiar signs are easy to recognise after a while:

- every section arrives in a group of three;
- each paragraph ends with a tidy summary sentence;
- ordinary facts are described as "crucial," "pivotal," or "transformative";
- simple verbs are replaced with phrases such as "serves as" and "plays a key role";
- the article says "it is not just X, but Y" even when X and Y would be clearer as two normal sentences;
- the conclusion promises an exciting future instead of saying what happens next.

I already use a Hermes `humanizer` skill for this kind of pass. The skill is helpful because it names patterns I might otherwise miss. It is not an authority on my voice, and it cannot decide whether a sentence is worth keeping because it came from a real experience.

### 5. Do a voice-protection pass

The final writing check is not "does this sound human?" It is more specific:

- Would I say this to another engineer?
- Did the edit remove a concrete detail because it was inconvenient?
- Are my opinions still visible?
- Does the article admit uncertainty where uncertainty exists?
- Could another person publish this under their name without changing anything?

That last question is a good warning sign. If the answer is yes, the draft may be clean but generic.

## How I would choose among the skills

The X post groups the skills by writing situation and suggests combinations. I would use that as a menu, not as a stack.

For a short note, a light pass such as `no-ai-slop` may be enough. For a research article, the more important combination is source checking plus structural editing, with anti-slop cleanup at the end. For a technical article, I want explicit protection for commands, code, terminology, and measured results.

The names in the visual list also need verification. I found plausible repositories for `stop-slop`, `no-ai-slop`, `humanizer`, `slopkit`, and `anti-ai-slop-writing`, but the original image does not provide canonical links for every entry. Similar names do not necessarily mean identical skills, and a repository's popularity does not establish that its instructions are safe or useful.

I do not need ten writing skills installed globally. I need a small, reviewable process that leaves evidence and voice intact.

## The standard I actually want

The best anti-slop edit is not the one that makes a reader wonder whether a language model was involved. It is the one that makes the article easier to trust.

That means:

- fewer claims that outrun their evidence;
- fewer sentences written for atmosphere rather than information;
- more details about what happened and what I did;
- clearer boundaries between fact, interpretation, and recommendation;
- prose that sounds like one person who has actually spent time with the system.

AI can help me find repetition, test an outline, and challenge weak explanations. It can also make every article sound competent in the same empty way. The editing workflow has to defend against both problems.

For this blog, human writing is not a texture applied at the end. It is the evidence, judgment, and point of view that made the article worth writing in the first place.

*Draft note: repository links and the comparison of individual skills need a final source review before publication.*
