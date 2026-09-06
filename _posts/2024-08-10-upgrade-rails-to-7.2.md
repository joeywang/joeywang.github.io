---
layout: post
title:  "Upgrading to Rails 7.2: Four Breaking Changes We Hit"
description: "Four breaking changes we hit upgrading to Rails 7.2: show_exceptions, array-containment SQL, connection pool locking, and assert_enqueued_email_with."
date:   2024-08-10 14:41:26 +0100
categories: [Rails]
tags: [rails, ruby, testing, debugging]
---

<audio controls preload="metadata" src="/assets/audio/upgrade-rails-to-7.2-summary.ogg">
  Your browser does not support the audio element.
</audio>

Four things broke moving from Rails 7.1 to 7.2.

### `show_exceptions` no longer takes true/false

Setting it to `false` used to mean exceptions raise instead of rendering an error page, which specs relied on. That behavior now needs `:none`.

```diff
   # Raise exceptions instead of rendering exception templates.
-  config.action_dispatch.show_exceptions = false
+  config.action_dispatch.show_exceptions = :none
```

### SQL generated for array containment changed

```diff
-    if link = where('course_ids @> \'{?}\'', course.id).first
+    if link = where('course_ids @> ARRAY[?]::bigint[]', course.id).first
```

### `lock_thread=` is gone from the connection pool

```bash
NoMethodError: undefined method `lock_thread=' for an instance of ActiveRecord::ConnectionAdapters::ConnectionPool
```

```diff
-    ActiveRecord::Base.connection.pool.lock_thread = false
+    # ActiveRecord::Base.connection.pool.lock_thread = false
```

### `assert_enqueued_email_with` takes `params`, not `args`

```diff
-    assert_enqueued_email_with UserMailer, :invitation, args: { invitation: invitation }
+    assert_enqueued_email_with UserMailer, :invitation, params: { invitation: invitation }
```

None of these needed a redesign, just a grep for each pattern across the codebase before merging the upgrade.
