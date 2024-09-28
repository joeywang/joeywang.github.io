---
layout: post
title: 'A Tale of Tabs and Tokens: My Journey Solving Authentication Puzzles in Single
  Page Applications'
date: 2024-09-28 21:37 +0100
categories: [Web Development, Authentication]
tags: [SPA, cookie, token]
---

# A Tale of Tabs and Tokens: My Journey Solving Authentication Puzzles in Single Page Applications

## The Curious Case of the Confused Classroom

As the lead developer for "LearnQuest," an innovative online learning platform, I found myself facing a peculiar challenge. My mission was to create a seamless experience for students eager to absorb knowledge across various subjects. But lately, I'd been losing sleep over a bizarre phenomenon...

Students were reporting a curious issue: They'd open multiple tabs to juggle between different lessons, but LearnQuest seemed to get... well, confused. It was as if the platform couldn't keep track of which student was studying what, leading to a chaotic learning experience. I started calling it "The Curious Case of the Confused Classroom."

As I dove deeper into this digital dilemma, I realized the culprit behind this confusion: cookies. Those small bits of data that were supposed to make life easier had become the very source of my troubles. It was time to embark on a quest to find a better solution!

## The Cookie Conundrum

Initially, LearnQuest relied on cookies to keep track of essential information:
- Lesson ID: What the student is currently studying
- Course ID: Which course the lesson belongs to
- Session ID: To keep the student logged in

Here's what my cookie-setting code looked like:

```javascript
// Setting cookies for session management
document.cookie = `lessonId=${currentLessonId}; path=/`;
document.cookie = `courseId=${currentCourseId}; path=/`;
document.cookie = `sessionId=${userSessionId}; path=/; HttpOnly`;
```

At first glance, cookies seemed like the perfect choice. They're easy to implement, widely supported, and can persist information across page reloads. But as I discovered, they came with their own set of challenges:

1. **The Tab Tango**: Cookies don't know how to dance between tabs. They share information across all tabs of the same origin, leading to a confusing waltz of data.

2. **The Security Samba**: Storing sensitive information in cookies can be like doing the samba on a tightrope - one misstep, and you could fall into a security vulnerability.

3. **The Storage Salsa**: With a limit of usually 4KB, cookies can quickly run out of dance floor space when you need to store more complex session data.

4. **The Performance Polka**: Cookies join every request to the server in a lively polka, but this can slow down the tempo of your application's performance.

It was clear that while cookies had been faithful partners, it was time to explore other dance partners for my authentication ball.

## Choreographing the Perfect Solution

After considering all the options, I decided to create a new, fusion dance style. Here's the choreography I developed for LearnQuest's authentication ballet:

1. **The Token Tango, with a Twist**:
   I implemented JWT for the main authentication dance.

   ```javascript
   // Function to set JWT in localStorage
   function setAuthToken(token) {
     localStorage.setItem('authToken', token);
   }

   // Function to get JWT from localStorage
   function getAuthToken() {
     return localStorage.getItem('authToken');
   }

   // Using the token in API calls
   fetch('/api/user-data', {
     headers: {
       'Authorization': `Bearer ${getAuthToken()}`
     }
   })
   .then(response => response.json())
   .then(data => console.log(data));
   ```

2. **The Session Storage Sidestep**:
   I used sessionStorage for tab-specific moves (lesson ID, course ID).

   ```javascript
   // When loading a lesson
   function setLessonContext(lessonId, courseId) {
     sessionStorage.setItem('currentLessonId', lessonId);
     sessionStorage.setItem('currentCourseId', courseId);
   }

   // Getting lesson context
   function getLessonContext() {
     return {
       lessonId: sessionStorage.getItem('currentLessonId'),
       courseId: sessionStorage.getItem('currentCourseId')
     };
   }
   ```

3. **The API Allemande**:
   I modified the API to expect specific dance instructions (session context) in request headers or parameters.

   ```javascript
   // Making an API call with lesson context
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

4. **The Troubleshooting Twist**:
   To make debugging easier, I added tracking for query strings and headers in our Sentry-like bug tracking system.

   ```javascript
   // Logging context to Sentry (or similar error tracking service)
   function logContextToSentry() {
     const { lessonId, courseId } = getLessonContext();
     Sentry.configureScope(scope => {
       scope.setTag('lessonId', lessonId);
       scope.setTag('courseId', courseId);
     });
   }

   // Call this function before making API requests
   logContextToSentry();
   ```

   This additional step allows us to correlate errors and issues with specific lessons and courses, making troubleshooting much more efficient.

## The Grand Finale

With this new choreography in place, LearnQuest was ready for its grand performance. Students could now open as many tabs as they liked, each one maintaining its own lesson context while staying in sync with the overall learning journey.

The backend was no longer confused - it knew exactly which lesson each student was focusing on at any given moment. The days of the "Confused Classroom" were over, replaced by a harmonious learning symphony across multiple tabs.

As the lead developer, I could finally get a good night's sleep, knowing that our students were engaged in a seamless, secure, and sensational learning experience.

The addition of context logging to our error tracking system proved invaluable. When issues did arise, I could quickly identify which lesson or course was involved, significantly reducing debugging time and improving our ability to provide support to students.

Remember, in the ever-evolving world of web development, today's perfect solution might be tomorrow's legacy system. I keep my dancing shoes on, stay curious, and always be ready to learn new steps in the authentication tango!
