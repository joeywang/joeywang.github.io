---
layout: post
title: "SCORM: What the E-Learning Standard Actually Does"
description: "SCORM is the packaging and tracking standard that lets e-learning content run and report progress consistently across different learning platforms."
date: 2024-08-27 00:00 +0000
categories: [Engineering]
tags: [scorm, e-learning, javascript]
---
<img src="assets/img/re/scorm_runtime.png" alt="course" />

<audio controls preload="metadata" src="/assets/audio/understanding-scorm-the-digital-learning-standard-summary.ogg">
  Your browser does not support the audio element.
</audio>

SCORM (Sharable Content Object Reference Model) is the packaging and communication standard that lets e-learning content run in a browser and report progress back to whatever learning management system is hosting it. The Advanced Distributed Learning initiative introduced it in 2000, and it's still the de facto standard for portable course content.

## What it gives you

- **Interoperability**: content built to SCORM runs on any SCORM-compliant LMS, not just the one it was authored for.
- **Reusability**: the same SCO (Sharable Content Object) can be dropped into different courses.
- **Tracking**: SCORM defines a standard way to report completion status and progress back to the LMS.

## The runtime environment

The SCORM runtime is the layer of software components that sit between the course content and the LMS, handling delivery, tracking, and reporting. It's built from a handful of parts:

1. **LMS integration**: the runtime has to talk to whatever LMS is hosting it.
2. **SCOs**: the individual learning units tracked within a course.
3. **SCO launch**: how a learner opens a given SCO.
4. **Navigation**: controls for moving between units of content.
5. **SCO status**: completion state per unit.
6. **Data reporting**: interaction and progress data sent back to the LMS.

In practice, this plays out as: the runtime initializes when a learner opens a course, launches individual SCOs (videos, quizzes, simulations), tracks progress as the learner interacts with them, and exchanges that data with the LMS as it goes.

## Where it falls short, and where it helps

SCORM content runs in any browser, on any compliant LMS, without per-platform rework, which is the main reason it has stuck around for two decades of e-learning tooling. The tradeoff is a communication API (SCORM's runtime API, `LMSInitialize`/`LMSSetValue`/`LMSCommit`/etc.) that shows its age; xAPI and cmi5 exist partly because SCORM's tracking model is limited to what fits in course-and-completion semantics.

If you're implementing a runtime rather than just consuming one, [scorm-again](https://github.com/jcputney/scorm-again) is a maintained JavaScript SCORM runtime library worth starting from instead of writing the API surface from scratch.
