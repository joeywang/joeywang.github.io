---
layout: post
title: "N+1 Queries in Rails: What Silently Breaks `includes`"
description: "How ActiveRecord's includes prevents N+1 queries in Rails, and the common mistakes with order, filtering, and pluck that silently break it."
date: "2025-01-06"
categories: [Rails]
tags: [rails, performance, database, debugging]
---
<audio controls preload="metadata" src="/assets/audio/n-plus-1-pitfalls-summary.ogg">
  Your browser does not support the audio element.
</audio>

`includes` fixes the N+1 query problem in Rails, until a second line of code quietly undoes it. The failure mode is not "forgot to use includes", it's "used includes correctly, then wrote the next line in a way that invalidates it."

## The problem

Take a `Program` that has many `courses`, each with a `teacher`:

```ruby
class Program < ApplicationRecord
  has_many :courses
end

class Course < ApplicationRecord
  belongs_to :program
  belongs_to :teacher
end

class Teacher < ApplicationRecord
  has_many :courses
end
```

Fetch programs and walk their courses to get teachers, and you get N+1:

```ruby
Program.limit(5).each do |program|
  program.courses.each do |course|
    puts course.teacher.name
  end
end
```

That's one query for programs, one query per program for its courses, and one query per course for its teacher. Five programs with ten courses each is `1 + 5 + (5 * 10) = 56` queries.

`includes` collapses that to three:

```ruby
Program.includes(courses: :teacher).limit(5).each do |program|
  program.courses.each do |course|
    puts course.teacher.name
  end
end
```

One query for programs, one for all their courses (`WHERE program_id IN (...)`), one for all the teachers (`WHERE id IN (...)`). 56 down to 3.

## What breaks it after the fact

### Calling `.order` after preloading

```ruby
# Bad: fires a new query per program
Program.includes(:courses).each do |program|
  program.courses.order(:name).each do |course|
    puts course.name
  end
end
```

`includes(:courses)` loads every course in one query. `.order(:name)` on the association re-queries per program anyway, because ordering an already-loaded association is treated as a new scope, not a sort of what's in memory. Order before loading instead:

```ruby
Program.includes(:courses).order("courses.name").each do |program|
  program.courses.each do |course|
    puts course.name
  end
end
```

### Filtering inside the loop

```ruby
# Bad: .where on a loaded association still queries
Program.includes(:courses).each do |program|
  active_courses = program.courses.where(active: true)
  active_courses.each { |course| puts course.name }
end
```

Same problem: `.where` on an association object is a new query, not a filter over what's already loaded. Push the condition into the original query instead:

```ruby
Program.joins(:courses).where(courses: { active: true }).each do |program|
  program.courses.each { |course| puts course.name }
end
```

### `.pluck` instead of `.map`

```ruby
# Bad: pluck bypasses the preloaded association entirely
programs = Program.includes(:courses)
programs.each do |program|
  course_names = program.courses.pluck(:name)
end
```

`.pluck` always hits the database; it has no concept of "this is already loaded." `.map` works on the in-memory records:

```ruby
programs = Program.includes(:courses)
programs.each do |program|
  course_names = program.courses.map(&:name)
end
```

## The pattern

All three mistakes share a cause: any method that builds a new ActiveRecord scope on an association, `.order`, `.where`, `.pluck`, discards the preloaded data and queries again. `includes` only helps for operations performed on the loaded array itself. Check query logs (or the `bullet` gem) after adding `includes`, not just before, because the eager load can be silently thrown away three lines later.
</content>
