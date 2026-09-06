---
layout: post
title: "delete_all vs destroy_all in Rails: Callbacks and Associations"
description: "delete_all skips callbacks and dependent associations while destroy_all runs them, and picking the wrong one silently breaks counter caches and cascades."
date: 2024-07-28 00:00 +0000
categories: [Rails]
tags: [rails, ruby, database, debugging]
---
<audio controls preload="metadata" src="/assets/audio/delete-all-and-destroy-all-summary.ogg">
  Your browser does not support the audio element.
</audio>

A count of active students that never updates, no error, no exception. The cause: `delete_all` where the code needed `destroy_all`. Same job on paper, different SQL and different guarantees underneath.

## `delete_all`

- Does not instantiate the records, one bulk `DELETE` statement.
- Skips `before_destroy` and `after_destroy` callbacks entirely.
- Ignores `dependent: :destroy` on associations, which can leave orphan rows.

## `destroy_all`

- Loads each record and calls `destroy` on it.
- Runs every callback.
- Respects `dependent: :destroy`, cascading the deletion to associated records.

## Which one you want

Use `delete_all` when you've checked that nothing depends on the callbacks or associations it skips, and you want the fastest possible bulk delete. Use `destroy_all` when callbacks or cascades matter: counter caches, `before_destroy` validations, anything downstream that expects to be notified.

## Foreign keys aren't a substitute

A `CASCADE` foreign key will delete child rows for you at the database level, and `RESTRICT` will block a delete that would orphan a row. Both protect data integrity, but neither runs your Rails callbacks, so they don't make the `delete_all`/`destroy_all` choice moot.

## The principle

The method name is the contract: `delete` is a SQL statement, `destroy` is a Ruby callback chain. Reach for `delete_all` only after confirming nothing depends on what it skips, a code review or a test that asserts the counter cache updates is cheaper than the bug it prevents.
