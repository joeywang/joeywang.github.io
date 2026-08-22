---
layout: post
title: "Could AI Simulate Billions of Possible Human Lives?"
date: 2026-08-22 09:14:00 +0000
author: "Joey Wang"
description: "An exploration of LLMs as compressed maps of human experience, and what a future branching world model might do with them."
tags: [ai, llm, world-models, multi-agent-systems, philosophy, future-of-work]
categories: [AI, Ideas]
---

<audio controls preload="metadata" src="/assets/audio/branching-lives-world-models-summary.ogg">
  Your browser does not support the audio element.
</audio>

I keep thinking about what a language model really contains.

At the surface, it is a system that predicts the next piece of text. It answers questions, summarizes documents, writes code, and imitates different styles of conversation. That description is technically useful, but it can also make the model seem smaller than it is.

A large language model has absorbed patterns from an enormous amount of human description. It has seen fragments of decisions, relationships, careers, conflicts, discoveries, failures, institutions, and ordinary days. It does not contain the lives of billions of people in any literal sense. Still, it has learned something like a compressed statistical map of how people describe the world and how one situation tends to lead to another.

That makes me wonder whether language models are the early version of something much larger: a system for exploring possible human futures.

## From text prediction to life trajectories

Imagine starting with a person in a particular situation:

- they are 25 years old;
- they have a software job and limited savings;
- their family lives in another country;
- they have an opportunity to move abroad;
- they are unsure whether to optimize for income, relationships, or stability.

The system could model several possible next steps:

```text
initial situation
├── move abroad
│   ├── career improves
│   ├── relationship becomes difficult
│   └── return home after two years
├── stay where they are
│   ├── start a business
│   ├── remain employed
│   └── spend more time caring for family
└── delay the decision
    ├── the opportunity disappears
    └── a better opportunity appears later
```

Every branch could split again. A new job could create a new relationship. A relationship could change a person's willingness to move. A health problem could change all of the priorities. A recession could remove options that previously looked safe.

The result would not be one prediction. It would be a distribution of plausible trajectories.

That distinction matters. The goal would not be to announce, "This is your future." It would be to show, "Under these assumptions, these futures become more likely, and these decisions have the greatest influence over the outcome."

## The LLM as a compressed map of human experience

This is where language models become interesting to me.

They are not merely storing facts. They have learned relationships between situations and responses. They have seen how people talk about fear, ambition, money, illness, love, status, failure, and loss. They have seen recurring patterns in personal stories and institutional behavior.

In that limited sense, an LLM contains fragments of a probabilistic model of human life.

But there is an important warning here: a plausible story is not the same as a correct simulation.

A model can generate a convincing explanation for why somebody changed jobs without actually understanding the causal mechanism. It can produce a realistic family conflict without knowing whether the conflict would happen in a particular family. It can describe a likely economic outcome while missing a political or technological event that changes the entire environment.

So the LLM would be useful as one component of a simulator, not as the simulator itself.

## The future system will need more than language

A serious life-trajectory simulator would probably require several different kinds of models:

```text
language model       communication and interpretation
vision model         physical environments and activities
audio model          speech, tone, and emotional signals
economic model       jobs, prices, resources, and incentives
social model         relationships, groups, and institutions
health model         bodies, risks, and changing capabilities
memory model         persistent personal history
planning model       actions and consequences
value model          goals, preferences, and constraints
```

The LLM would remain important because language is how humans explain goals, uncertainty, and meaning. But it would become one interface into a broader world model.

A future assistant might not only answer:

> "What should I do?"

It might also help explore:

> "What happens to my family, finances, health, and sense of purpose under each option over the next five years?"

That is a much harder question. It is also closer to the questions people actually struggle with.

## Why the number of branches is not the main problem

At first, it sounds impossible to simulate billions of lives. There are too many people, too many decisions, and too many possible futures.

But the system would not need to enumerate every possible branch. It could prioritize branches according to the question being asked:

- the most probable outcomes;
- the most consequential outcomes;
- rare but dangerous outcomes;
- surprising outcomes that challenge the current assumptions;
- branches that could be changed by a practical intervention.

The valuable output might be a small set of scenarios rather than billions of detailed stories.

For example, a career simulator might discover that the job title is not the most important variable. The decisive variables might instead be health, savings, family support, and the ability to keep learning. That insight is more useful than a beautiful narrative about one imagined future.

## The danger of turning history into destiny

There is also a serious risk.

If a simulator learns from historical data, it may reproduce historical inequalities and present them as neutral probabilities. It might conclude that a group is less likely to succeed because that group was previously denied opportunities. It could mistake an unfair constraint for an inherent human tendency.

A responsible system would need to separate several things:

- what happened in the past;
- what caused it to happen;
- which constraints were unjust or temporary;
- what could change if the constraints were removed;
- which assumptions are still valid today.

Otherwise, the simulator would quietly become a machine for preserving the past.

There is another risk: if everyone follows the same predictions, the predictions change. If a model tells millions of people that a city will become desirable, their actions may make the prediction come true. Or they may make the city unaffordable and destroy the conditions behind the original forecast.

The model becomes part of the world it is trying to predict.

## A simulator should reveal choices, not remove them

The dangerous version of this technology would tell someone what their life will be.

The useful version would show uncertainty and leverage:

```text
scenario: accept the new job
confidence: medium
positive effects: income, learning, professional network
risks: less family time, relocation stress
most sensitive variable: partner's willingness to move
possible intervention: test the arrangement for six months
```

The system should expose its assumptions, show competing scenarios, and explain what information would change its conclusion.

It should also preserve the difference between:

- observed evidence;
- statistical inference;
- model-generated possibilities;
- a person's own values;
- and an actual decision.

A model can estimate consequences. It cannot decide what a meaningful life is for another person.

## Humans may eventually speak to machines more precisely

I also think the interface will change.

Natural language is powerful because it is flexible. It lets us communicate uncertainty, emotion, humor, and context. But it is also ambiguous and inefficient for precise tasks.

A household robot might eventually translate a natural request into something more structured:

```yaml
goal: prepare dinner
constraints:
  allergies: [peanuts]
  time_limit: 30 minutes
  budget: moderate
preferences:
  children: mild flavor
  adults: high protein
priority:
  - nutrition
  - family preference
  - convenience
requires_approval:
  - purchases over budget
```

Humans may not need to learn a strange machine language directly. We may speak normally, while the machine compiles our words into goals, constraints, permissions, and executable plans.

However, I do not think formal instructions will replace human language. Affection, moral intuition, humor, and changing feelings are not just inefficient data formats. They are part of what we are trying to communicate.

The likely future is a combination:

> Humans communicate naturally. Machines translate that communication into precise internal representations, simulations, and actions.

## The family robot problem

This becomes especially important when the machine lives with a family.

A useful family assistant would need to understand more than commands. It would need to model routines, relationships, permissions, moods, and boundaries:

```text
person: parent
values: family time, reliability, learning
current state: tired
allowed actions: reminders, shopping suggestions
requires approval: purchases, messages, medical decisions
```

That kind of persistent household model could be very helpful. It could also become one of the most sensitive information systems a person owns.

Who can inspect the memory? Who can delete it? Does every family member consent? What happens when the robot misunderstands a relationship? Which decisions must always remain human decisions?

The intelligence of the robot is only part of the problem. Its authority and memory boundaries may matter more.

## From storyteller to world model

Today, an LLM is often best understood as a powerful storyteller and reasoning interface. It can describe many possible lives because it has learned patterns from human descriptions.

The next step is a model connected to more of the world:

- persistent memory;
- real observations;
- physical environments;
- economic and social data;
- simulations of other agents;
- explicit goals and constraints;
- and feedback from what actually happens.

That would be closer to a world model than a text generator.

I do not expect the first useful version to simulate every detail of every person. It may begin with narrower systems: city planning, logistics, education, health scenarios, business strategy, or personal decision support.

Over time, these systems may become increasingly personal and increasingly interactive. They may help us rehearse choices before making them, discover risks we have overlooked, and understand the trade-offs hidden inside ordinary decisions.

## The map is not the life

The idea is exciting because it could help people see consequences that are difficult to imagine alone.

It is dangerous for the same reason.

A generated life trajectory can look persuasive even when it is based on weak assumptions. A probability can feel like a judgment. A simulation can make a person seem like a predictable object instead of a living individual who can change.

So I keep coming back to one principle:

> A simulated life is a map of possibilities, not the person and not the future.

The best system would not use probability to close the future. It would use probability to show where the future is still open.

That may be the real promise of this idea: not creating billions of artificial lives for their own sake, but helping real people understand the branches in front of them — and which choices can still change the direction of the story.
