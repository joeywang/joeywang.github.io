---
layout: post
title: "Laravel Model: `save()` vs. `saveOrFail()`"
description: "When Laravel's save() silently returns false versus when saveOrFail() throws, and how to pair both with validation and database transactions."
date: "2025-01-05"
categories: [Engineering]
tags: [php, laravel, database]
---
<audio controls preload="metadata" src="/assets/audio/save-saveorfail-summary.ogg">
  Your browser does not support the audio element.
</audio>

Laravel Eloquent gives you two ways to persist a model: `save()` and `saveOrFail()`. They look interchangeable. They are not, and the difference is entirely about what happens when the write fails.

## `save()`

`save()` returns a boolean. It does not throw on failure, which means a failed save is invisible unless you explicitly check the return value.

```php
$user = new User();
$user->name = "John Doe";
$user->email = "invalid-email"; // Assume this is invalid
if (!$user->save()) {
    echo "Save failed, but no exception was thrown.";
}
```

`save()` does not run validation. If the write fails, for example on a database constraint, it just returns `false`. Skip the check and the failure disappears silently.

## `saveOrFail()`

`saveOrFail()` does the same write, then throws if it fails, rather than returning `false`:

```php
try {
    $user = new User();
    $user->name = "John Doe";
    $user->email = "invalid-email"; // Assume this is invalid
    $user->saveOrFail();
} catch (\Throwable $e) {
    echo "Exception caught: " . $e->getMessage();
}
```

It fails on database constraints (unique, foreign key, `NOT NULL`), mass assignment violations, and query errors. It does not fail on validation, that is still `Validator`'s job, and it does not fail at all when there's no database-level error, regardless of whether the data makes semantic sense.

## Data integrity needs both constraints and validation

Neither method substitutes for the other layer. Database constraints exist to catch what application code misses:

```php
Schema::create('users', function (Blueprint $table) {
    $table->id();
    $table->string('name');
    $table->string('email')->unique(); // Unique constraint
    $table->timestamps();
});
```

Validation catches bad input before it reaches the database at all:

```php
use Illuminate\Support\Facades\Validator;

$data = ['email' => 'invalid-email'];

$validator = Validator::make($data, [
    'email' => 'required|email|unique:users,email',
]);

if ($validator->fails()) {
    throw new \Exception($validator->errors()->first());
}

try {
    $user = new User();
    $user->email = $data['email'];
    $user->saveOrFail();
} catch (\Throwable $e) {
    echo "Exception caught: " . $e->getMessage();
}
```

And when multiple writes depend on each other, wrap them in a transaction so a failure at any point rolls back the whole set:

```php
use Illuminate\Support\Facades\DB;

DB::transaction(function () {
    $user = new User();
    $user->name = "John Doe";
    $user->email = "johndoe@example.com";
    $user->saveOrFail();

    $profile = new Profile();
    $profile->user_id = $user->id;
    $profile->bio = "New user bio";
    $profile->saveOrFail();
});
```

`saveOrFail()` is what makes the rollback trigger reliably here: if the second `saveOrFail()` throws, the transaction rolls back the first write too.

## The Rails comparison

Laravel's `saveOrFail()` maps onto Ruby on Rails' `save!`:

```ruby
user = User.new(name: "John Doe", email: "invalid-email")
user.save  # Returns false if saving fails

user.save!  # Raises an exception if saving fails
```

Rails' naming is the clearer design here. The `!` convention marks "this method raises" consistently across the framework, so a Rails developer already knows what `save!` does before reading its docs. `saveOrFail()` works the same way but doesn't say so in its name.

## Comparison

| Feature                     | `save()` | `saveOrFail()` |
|-----------------------------|----------|----------------|
| Returns boolean              | Yes      | No (throws instead) |
| Throws on failure            | No       | Yes |
| Catches validation errors    | No       | No, use `Validator` |
| Rolls back cleanly in a transaction | Not automatically | Yes |

Use `save()` when you want to handle failure manually, logging instead of raising. Use `saveOrFail()` when a failed write must not pass silently, particularly inside transactions where a swallowed `false` would leave a half-committed operation looking like it succeeded.
</content>
