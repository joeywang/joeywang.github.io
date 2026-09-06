---
layout: post
title: "Fixing Multi-Tab Session Bugs with JWT and sessionStorage"
description: "How cookie-based session state breaks when a user opens multiple tabs in a single-page app, and how splitting auth into JWT plus sessionStorage fixes it."
date: 2024-09-28 21:37 +0100
categories: [Security]
tags: [javascript, security, debugging]
---

<audio controls preload="metadata" src="/assets/audio/a-tale-of-tabs-and-tokens-summary.ogg">
  Your browser does not support the audio element.
</audio>


A single-page app that keeps session state in cookies breaks in a specific, predictable way: open two tabs on two different lessons, and the second tab's cookie write overwrites the first. Cookies are shared across every tab of the same origin, so whichever tab wrote last wins, and the other tab quietly starts acting on the wrong lesson ID. That was the actual bug on an online course platform I worked on: students opened multiple lessons in separate tabs, and the backend lost track of which tab belonged to which lesson.

## Why cookies are the wrong tool here

The original code stored three things in cookies:

```javascript
// Setting cookies for session management
document.cookie = `lessonId=${currentLessonId}; path=/`;
document.cookie = `courseId=${currentCourseId}; path=/`;
document.cookie = `sessionId=${userSessionId}; path=/; HttpOnly`;
```

Cookies are easy to set and survive reloads, but for this use case they have four real problems:

- They are shared across every tab of the same origin, so tab-specific state (which lesson is open) gets clobbered by whichever tab wrote last.
- Anything in a non-`HttpOnly` cookie is readable by client-side script, which makes them a bad place for identifiers you don't want tampered with.
- The practical size limit is around 4KB, tight once you need more than a few fields.
- Every cookie is sent with every request to the same domain, adding overhead you don't need on most calls.

## Splitting session identity from tab context

The fix was to stop treating "who is logged in" and "what is this tab looking at" as the same kind of state.

Auth token in `localStorage`, shared across tabs because logging in is genuinely a per-user, not per-tab, fact:

```javascript
function setAuthToken(token) {
  localStorage.setItem('authToken', token);
}

function getAuthToken() {
  return localStorage.getItem('authToken');
}

fetch('/api/user-data', {
  headers: {
    'Authorization': `Bearer ${getAuthToken()}`
  }
})
  .then(response => response.json())
  .then(data => console.log(data));
```

Lesson and course context in `sessionStorage`, which is scoped per tab by design:

```javascript
function setLessonContext(lessonId, courseId) {
  sessionStorage.setItem('currentLessonId', lessonId);
  sessionStorage.setItem('currentCourseId', courseId);
}

function getLessonContext() {
  return {
    lessonId: sessionStorage.getItem('currentLessonId'),
    courseId: sessionStorage.getItem('currentCourseId')
  };
}
```

Every API call that depends on lesson context now reads from `sessionStorage` and sends it explicitly, instead of relying on a cookie to imply it:

```javascript
function fetchLessonProgress() {
  const { lessonId, courseId } = getLessonContext();
  fetch(`/api/progress?lessonId=${lessonId}&courseId=${courseId}`, {
    headers: {
      'Authorization': `Bearer ${getAuthToken()}`,
      'X-Lesson-Id': lessonId,
      'X-Course-Id': courseId
    }
  })
    .then(response => response.json())
    .then(data => updateProgressUI(data));
}
```

## Tagging errors with the same context

Once lesson and course IDs are explicit values instead of implicit cookie state, they can go straight into error tracking:

```javascript
function logContextToSentry() {
  const { lessonId, courseId } = getLessonContext();
  Sentry.configureScope(scope => {
    scope.setTag('lessonId', lessonId);
    scope.setTag('courseId', courseId);
  });
}

logContextToSentry();
```

That one change made debugging noticeably faster: an error report now names the lesson and course it came from, instead of a session ID you have to cross-reference against logs by hand.

## The actual lesson

Cookies are the wrong default for per-tab state, not because they're insecure but because they're scoped to the origin, not the tab. If two tabs need to disagree about what they're looking at, that state has to live somewhere tab-scoped, `sessionStorage`, not somewhere origin-scoped, a cookie. Authentication is a different kind of state, genuinely shared across tabs, and a bearer token in `localStorage` models that correctly. Keeping those two categories separate fixed the bug; everything else was plumbing.
