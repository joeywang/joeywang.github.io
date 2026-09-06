---
layout: post
title:  "Fragment Caching a Large List That Changes Constantly"
description: "How splitting static and dynamic fields, granular fragment caching, and incremental loading keep a large, frequently updated list fast without stale data."
date:   2024-05-06 14:41:26 +0100
categories: [Rails]
tags: [rails, redis, performance, database]
---

<audio controls preload="metadata" src="/assets/audio/dynamic-update-for-performance-summary.ogg">
  Your browser does not support the audio element.
</audio>

A page listing lessons works fine at 200 rows. At 1000, with per-user dynamic fields like status and score updating constantly, the same approach starts to strain both the server and the client. The fix is separating what changes rarely from what changes on every request, and caching each at the right level.

### Split static from dynamic

Most of a lesson's data doesn't change: title, description, structure. What changes is per-student progress: status, score. Cache the static part with `Rails.cache` and invalidate it only when the lesson itself changes, not on every student update. Mixing the two into one cache entry means every score update busts a cache full of data that never changed.

### Fragment cache with a key that matches the blast radius

Store the rendered lesson fragment in Redis keyed by both student ID and lesson ID. Keying it this way means updating one student's progress does not invalidate anyone else's cached fragment:

```ruby

# When a lesson is updated
def update_lesson(lesson, attributes)

  lesson.update!(attributes)

  expire_fragment(["lesson", lesson.id]) # Invalidate the specific lesson fragment cache

end

```

Invalidating the whole cache on any change is the easy path, and the one that erases the benefit of caching in the first place.

### Load static content first, patch in the dynamic part

Render the page from cache, then fetch only what changed:

```javascript

function fetchUpdatedLessons() {

  fetch('/api/lessons/updated')

    .then(response => response.json())

    .then(data => {

      data.forEach(lesson => {

        updateLessonDOM(lesson); // A function to update the lesson's DOM node

      });

    });

}

// Call this function periodically or on specific triggers

setInterval(fetchUpdatedLessons, 10000); // Every 10 seconds

```

An endpoint that returns only lessons changed since the last check keeps the payload small regardless of how many lessons exist in total. If updates need to show up immediately rather than on a ten-second poll, replace the interval with a WebSocket push.

### Where else the volume shows up

- Index the columns you filter or sort lessons by; a table scan that was fine at 200 rows is not fine at 1000.
- Use a read replica if the read volume from this page competes with writes elsewhere.
- Paginate or infinite-scroll rather than rendering every lesson at once; the DOM cost of 1000 nodes is real even if the query is fast.
- Re-render only the lesson rows that actually changed, not the whole list, when the update comes back.

None of this replaces testing the cache under real invalidation patterns. A caching strategy that hasn't been tested against concurrent updates is a caching strategy that will eventually serve someone else's score.
