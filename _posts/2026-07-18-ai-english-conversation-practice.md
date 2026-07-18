---
layout: post
title: "Building an AI English Conversation Practice App"
date: 2026-07-18 16:55:00 +0100
author: "Joey Wang"
description: "Notes on building an AI speaking practice app: STT, TTS, Gemini, ElevenLabs, latency, topic control, and useful feedback for oral English learners."
tags: [ai, english-learning, speech-to-text, text-to-speech, gemini, llm, language-learning]
categories: [AI, Engineering]
---

# Building an AI English Conversation Practice App

I have been thinking about an AI English conversation practice app.

Not another chatbot with a microphone button. I mean something closer to a patient speaking partner: it talks with the learner about a topic, keeps the conversation moving, corrects gently, and helps the speaker build confidence in oral English.

That sounds simple until you try to build it.

A normal text chatbot can wait two or three seconds and nobody cares too much. A speaking app cannot. If the student says something and then the app sits there silently, it feels broken. Real conversation has rhythm. Even a small delay feels awkward.

So the technical problem is not just "use an LLM." The real problem is the whole voice loop:

```text
student speaks
  -> speech to text
  -> LLM understands and replies
  -> text to speech
  -> student hears the answer
```

Every step adds latency. Every step can also make the learning experience worse if it is not designed carefully.

## What the app should do

The goal is not to test the learner like an exam robot.

The goal is to create a safe conversation space where the student can speak more.

A useful session might look like this:

```text
Topic: ordering food in a restaurant
Level: A2 / B1
Goal: practise asking questions and responding naturally

AI: What kind of restaurant do you want to go to tonight?
Student: I want go Italian restaurant.
AI: Nice. You can say, "I want to go to an Italian restaurant." What dish would you order there?
```

The AI has to do several jobs at once:

- keep the conversation close to the topic
- adapt to the student's level
- avoid long monologues
- correct mistakes without killing confidence
- ask follow-up questions
- evaluate speaking performance
- make the whole thing feel fast enough

That is a lot of pressure on the design.

## The basic stack

There are three main components:

```text
Speech to text  ->  LLM  ->  Text to speech
```

Each has several candidates.

## Speech to text candidates

### Whisper API

Whisper is the obvious starting point. It works well, supports many accents, and is easy to reason about.

Pros:

- good accuracy
- handles non-native English reasonably well
- easy to host yourself if needed
- lots of deployment examples

Cons:

- not always fast enough for live conversation
- streaming support depends on the implementation
- self-hosting needs GPU if you want low latency at scale
- batch transcription creates an awkward pause after each student turn

For a first version, Whisper is fine. For a really smooth speaking experience, I would worry about latency early.

### Self-hosted Whisper

Self-hosting is attractive because speech data can be sensitive. It also gives more control over cost.

A small model can run cheaply, but accuracy drops. A larger model improves quality but needs more compute. This becomes a product decision, not just an engineering decision.

If the app is for serious learners, bad transcription is painful. The student says something correctly, the system hears it wrong, then gives useless feedback. That breaks trust quickly.

### Browser speech recognition

The browser can sometimes do speech recognition directly, depending on platform support.

Pros:

- very low integration effort
- can feel fast
- no audio upload for some implementations
- useful for prototypes

Cons:

- inconsistent browser support
- not fully under your control
- quality varies by device and language settings
- difficult to build a reliable commercial product around it

I like this for prototypes or fallback, but I would not want the whole product to depend on it.

### Gemini native audio

Gemini is interesting because it can combine parts of the voice loop. Instead of treating speech-to-text, LLM, and text-to-speech as three separate systems, the model can work more directly with audio and conversation.

Pros:

- fewer moving parts
- potentially lower latency
- more natural turn-taking
- can reason over speech and context together

Cons:

- availability depends on region and account
- API behavior changes faster than classic STT/TTS tools
- harder to swap one component independently
- product design becomes tied to one provider

This is probably where the best experience will come from eventually. But I would still keep an abstraction layer so the app is not trapped.

## LLM candidates

The LLM is the speaking partner and teacher.

It has to be fast, cheap enough, and good at controlled conversation. It also needs to evaluate language without becoming annoying.

### Gemini Flash

Gemini Flash is a strong candidate for this use case.

Pros:

- fast
- good cost profile
- strong multilingual understanding
- works well for short interactive turns
- can fit nicely with Google's audio stack

Cons:

- regional availability can be a problem
- output needs guardrails, or it may over-explain
- evaluation quality must be tested carefully

For conversation practice, speed matters more than writing the most beautiful paragraph. A slightly less powerful model that responds quickly may produce a better learning experience than a smarter model that pauses too long.

### Gemini Pro or larger models

A larger model may be useful for evaluation, lesson planning, or post-session feedback.

But I would be careful about using it in the live loop.

The live loop needs short responses. The evaluation loop can happen after the conversation.

That suggests two-model architecture:

```text
live conversation -> fast model
after-session review -> stronger model
```

The fast model keeps the rhythm. The stronger model gives better feedback after the student is done speaking.

### Other LLMs

OpenAI, Claude, and other models can all work here. The deciding factors are not only intelligence.

I would compare them on:

- response latency
- streaming quality
- cost per minute of conversation
- ability to stay in role
- quality of correction
- tool/API reliability
- region availability

For this kind of app, latency and controllability may matter more than benchmark scores.

## Text to speech candidates

### ElevenLabs

ElevenLabs is the quality benchmark in many demos.

Pros:

- very natural voices
- expressive speech
- good for role-play and realistic conversation
- can make the AI feel less robotic

Cons:

- cost can add up quickly
- latency needs testing
- voice quality may be overkill for some learning flows
- another provider in the critical path

For premium conversation practice, ElevenLabs is tempting. A natural voice can make students more willing to talk. But it is hard to ignore cost if users practise for many minutes every day.

### Browser text to speech

Browser TTS is the cheap and simple option.

Pros:

- almost free
- fast
- no server-side TTS cost
- good enough for prototypes

Cons:

- voices vary a lot by device
- pronunciation quality is inconsistent
- limited emotional range
- less control over speaking style

This may be a good fallback. It is not the voice I would use to impress a learner, but it can keep the loop fast.

### Google / Gemini speech

If Gemini can handle more of the audio loop, it may reduce the need for a separate TTS provider.

Pros:

- simpler architecture
- potentially lower latency
- fewer provider handoffs
- better alignment between model response and speech output

Cons:

- less flexibility if you want a specific voice style
- depends on regional availability
- harder to compare component quality independently

If the goal is a smooth real-time tutor, this is worth testing seriously.

## The latency problem

Latency is the hardest part.

The naive system waits for each stage to finish:

```text
record full answer
wait for transcription
wait for LLM
wait for TTS
play audio
```

That feels slow.

A better system overlaps work wherever possible.

```text
student starts speaking
  -> partial transcription begins
  -> model starts preparing once enough intent is clear
  -> response streams out
  -> TTS starts before the full answer is complete
```

The goal is not only to reduce actual latency. It is also to reduce perceived latency.

## Perceived latency tricks

Humans tolerate pauses better when they know the other person is still present.

In a voice app, silence is dangerous. It feels like the app crashed.

A few tricks help:

### 1. Use short filler responses

The AI can acknowledge quickly:

```text
"Okay, I see."
"Good answer. Let me help you say that more naturally."
"Nice, keep going."
```

This buys time while the system prepares the real response.

The filler must be careful. Too much filler becomes annoying. But a small acknowledgement makes the interaction feel alive.

### 2. Stream everything

Streaming should happen at every layer possible:

- stream speech recognition partials
- stream LLM output
- stream TTS audio

The best version starts speaking before the whole answer is generated.

### 3. Keep AI replies short

A speaking partner should not lecture.

Long answers are bad for latency and bad for learning. The AI should usually reply with one correction and one follow-up question.

For example:

```text
Student: I go to supermarket yesterday.
AI: Good. Say "I went to the supermarket yesterday." What did you buy there?
```

That is enough. Do not turn every mistake into a grammar lesson.

### 4. Use endpointing well

The system has to know when the student has finished speaking.

If it waits too long, the app feels slow. If it cuts in too early, it feels rude.

Voice activity detection and endpointing are not small details. They are part of the product experience.

### 5. Split live feedback and final evaluation

Do not do a full IELTS-style evaluation after every sentence.

During the conversation, keep feedback light:

- one correction
- one better phrase
- one follow-up question

After the session, give a fuller evaluation:

- fluency
- pronunciation notes if available
- grammar patterns
- vocabulary range
- confidence
- suggested next topics

This keeps the live conversation fast.

## Keeping the conversation on topic

A language practice app needs boundaries.

If the topic is "job interview practice," the AI should not drift into random chat. But it also should not sound like a form.

I would represent the session like this:

```json
{
  "topic": "ordering food in a restaurant",
  "level": "A2",
  "goal": "practice polite requests",
  "target_phrases": [
    "Could I have...?",
    "I would like...",
    "Can you recommend...?"
  ],
  "avoid": [
    "long grammar lectures",
    "advanced idioms"
  ]
}
```

Then every model turn gets a compact instruction:

```text
Stay on the topic. Ask one follow-up question. Correct at most one mistake. Keep the reply under 25 words unless the student asks for explanation.
```

That one rule, "correct at most one mistake," is important. Learners need confidence more than they need every sentence dissected.

## Evaluation is harder than it looks

It is easy to ask an LLM to "score the student's English." It will produce a score. That does not mean the score is good.

A useful evaluation should be specific and consistent.

Instead of:

```text
Your grammar is 7/10.
```

I want:

```text
You often used present tense for past events:
- "I go yesterday" -> "I went yesterday"
- "I buy it last week" -> "I bought it last week"

Practice: tell three short stories using past tense.
```

That feedback is useful because the student knows what to do next.

The evaluation prompt should look for patterns, not isolated mistakes.

Good categories:

- fluency: did the student keep speaking?
- grammar patterns: repeated mistakes
- vocabulary: repeated simple words or useful new phrases
- pronunciation: only if the audio system can support it reliably
- confidence: hesitation, very short answers, avoidance
- next practice: one concrete exercise

## A possible architecture

For version one, I would build two modes.

### Mode 1: practical and modular

```text
Browser records audio
  -> STT service, probably Whisper or hosted equivalent
  -> fast LLM, probably Gemini Flash
  -> TTS, maybe ElevenLabs or browser TTS
  -> browser plays response
```

This is easier to debug because each component is separate.

### Mode 2: low-latency native audio

```text
Browser audio stream
  -> Gemini audio / live API
  -> streamed audio response
```

This may become the better experience, but I would test it after the modular version. If something goes wrong in the native audio path, it can be harder to know whether the problem is transcription, reasoning, voice, or turn-taking.

## The stack I would test first

I would not start with the most expensive or most complex setup.

I would test three stacks:

| Stack | STT | LLM | TTS | Why test it |
|---|---|---|---|---|
| Cheap prototype | Browser speech recognition | Gemini Flash | Browser TTS | Fast to build, almost no cost |
| Quality modular | Whisper / hosted STT | Gemini Flash | ElevenLabs | Good quality, easier to debug |
| Low-latency future | Gemini audio | Gemini live model | Gemini audio | Best chance of natural turn-taking |

Then I would measure:

- time from student stop speaking to first AI audio
- transcription quality for non-native English
- cost per 10-minute session
- how often the AI over-corrects
- how often it drifts from the topic
- whether learners feel comfortable speaking more

That last metric matters most. If students speak more, the app is working.

## Final thoughts

The hard part of an AI English speaking app is not getting a model to answer.

The hard part is making the conversation feel safe, quick, and useful.

The AI needs to be fast enough that the learner does not feel abandoned. It needs to correct enough to help, but not so much that the student stops talking. It needs to stay close to the topic without sounding like a worksheet.

That is why the stack matters. Whisper, Gemini, ElevenLabs, browser speech APIs: they are not just technical choices. They shape how confident the learner feels.

For this kind of product, confidence is the real feature.
