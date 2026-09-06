---
layout: post
title: 'Soft Delete in Rails: Discard vs ActsAsParanoid'
description: "A comparison of Discard and ActsAsParanoid, the two common Rails soft-delete gems, and the query and unscope pitfalls each one introduces."
date: 2024-02-04 00:00 +0000
categories: [Rails, Database]
tags: [rails, ruby, database, debugging]
---
<audio controls preload="metadata" src="/assets/audio/soft-delete-solutions-discard-or-actasparanoid-summary.ogg">
  Your browser does not support the audio element.
</audio>


Soft delete flags a record as gone instead of removing it: a `discarded_at` or `deleted_at` column that regular queries filter out but that a restore action or an audit trail can still reach. It survives accidental deletes, keeps foreign keys intact, and gives you a "trash" feature for free. Rails has two common gems for it, Discard and ActsAsParanoid, and they solve the same problem differently enough that picking the wrong one costs you later.

## Discard

Discard adds a `discarded_at` column and otherwise stays out of the way.

```ruby
class User < ApplicationRecord
  include Discard::Model
  has_many :posts, dependent: :destroy
end

user = User.create(name: "John")
user.discard        # sets discarded_at
user.discarded?     # => true
User.kept           # non-discarded users
user.undiscard
```

It respects `dependent: :destroy`, so associated records get discarded too, and it gives you `kept`/`discarded` scopes. It does not add a default scope: nothing is hidden from you unless you explicitly query `kept`.

## ActsAsParanoid

ActsAsParanoid adds a `deleted_at` column and, unlike Discard, applies a default scope that hides discarded records everywhere unless you say otherwise.

```ruby
class Post < ActiveRecord::Base
  acts_as_paranoid
end

post = Post.create(title: "Hello")
post.destroy          # sets deleted_at
Post.only_deleted      # only soft-deleted posts
post.recover
post.really_destroy!   # actually gone
```

`really_destroy!` bypasses soft delete entirely. `with_deleted` and `only_deleted` reach past the default scope when you need to.

## The default scope is the real decision

The API differences are minor. The default scope is not. ActsAsParanoid hides deleted records everywhere unless you opt out; Discard hides nothing unless you opt in with `kept`. That single choice explains most of the bugs people hit with soft delete:

- `User.delete_all` does nothing special under Discard: it's a plain ActiveRecord method that never learned about `discarded_at`, so it deletes the rows for real. Only `.discard_all` behaves the way the name suggests.
- Under ActsAsParanoid, `unscoped` removes the soft-delete scope along with every other scope on the relation, so `User.where.not(address: nil).unscoped.first` can hand you back a discarded record with a nil address. `unscoped` doesn't know it was only supposed to touch the paranoid scope.
- Row counts and volume estimates go wrong under either gem if nobody accounts for the soft-deleted rows still sitting in the table.

## The trade-off

Soft delete looks free once it's wired up, but every table with a `deleted_at` column is a table where every future query, index, and migration has to remember it. Indexes need the deleted flag in their `WHERE` clause or they stop being selective. The rows never leave, so the table keeps growing until someone writes a job to purge old soft-deleted records. And the audit trail soft delete implies is only as good as the discipline behind it: a flag with no record of who set it isn't an audit trail, it's just a hidden column.

Pick Discard when you want soft delete to be explicit and rare. Pick ActsAsParanoid when you want deleted records to disappear from the whole app by default. Either way, write the test that proves `delete_all` and `unscoped` do what you think they do, because that's where soft delete quietly breaks.
