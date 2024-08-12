---
layout: post
title:  "Upgrade Rails to 7.2.0"
date:   2024-08-10 14:41:26 +0100
categories: Rails
---

1. Remove deprecated support to set Rails.application.config.action_dispatch.show_exceptions to true and false.

Exception won't be raised in specs

```diff
   # Raise exceptions instead of rendering exception templates.
-  config.action_dispatch.show_exceptions = false
+  config.action_dispatch.show_exceptions = :none
```


2. SQL generated is changed

```diff
-    if link = where('course_ids @> \'{?}\'', course.id).first
+    if link = where('course_ids @> ARRAY[?]::bigint[]', course.id).first
```

3. no lock_thread

```bash
NoMethodError: undefined method `lock_thread=' for an instance of ActiveRecord::ConnectionAdapters::ConnectionPool

```

```diff
-    ActiveRecord::Base.connection.pool.lock_thread = false
+    # ActiveRecord::Base.connection.pool.lock_thread = false
```

4. assert_enqueued_email_with: args vs. params

```diff
-    assert_enqueued_email_with UserMailer, :invitation, args: { invitation: invitation }
+    assert_enqueued_email_with UserMailer, :invitation, params: { invitation: invitation }
```
            

