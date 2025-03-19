---
layout: post
title: "Avoiding N+1 Queries in Rails: Common Pitfalls and Best Practices"
date: "2025-01-06"
categories: rails optimization activerecord
---
# Avoiding N+1 Queries in Rails: Common Pitfalls and Best Practices

## Introduction
One of the most common performance pitfalls in Ruby on Rails applications is the **N+1 query problem**. ActiveRecord provides powerful tools like `includes`, `preload`, and `eager_load` to mitigate this, but sometimes, developers unknowingly break eager loading, causing unnecessary database queries.

In this article, we'll explore common mistakes that break eager loading and how to fix them with best practices.

---

## Understanding the N+1 Query Problem
Let's say we have a `Program` model that has many `courses`, and each `Course` has a `Teacher`:

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

If we fetch `programs` and iterate over their courses to get teachers, we may introduce an N+1 query issue:

```ruby
Program.limit(5).each do |program|
  program.courses.each do |course|
    puts course.teacher.name
  end
end
```

### **Generated Queries (N+1 Problem)**
1. One query to fetch programs:
   ```sql
   SELECT * FROM programs LIMIT 5;
   ```
2. One query per program to fetch courses:
   ```sql
   SELECT * FROM courses WHERE program_id = 1;
   ```
3. One query per course to fetch the teacher:
   ```sql
   SELECT * FROM teachers WHERE id = ?;
   ```

If we have **5 programs, each with 10 courses**, this results in **1 + 5 + (5 * 10) = 56 queries!**

---

## Fixing N+1 Issues with `includes`
We can solve this problem using `includes`:

```ruby
Program.includes(courses: :teacher).limit(5).each do |program|
  program.courses.each do |course|
    puts course.teacher.name
  end
end
```

### **Optimized Queries with `includes`**
1. Fetch programs:
   ```sql
   SELECT * FROM programs LIMIT 5;
   ```
2. Fetch all related courses in **one** query:
   ```sql
   SELECT * FROM courses WHERE program_id IN (1, 2, 3, 4, 5);
   ```
3. Fetch all teachers in **one** query:
   ```sql
   SELECT * FROM teachers WHERE id IN (...);
   ```

This reduces queries from **56 down to 3!** 🚀

---

## **Common Mistakes That Break Preloading**
Even with `includes`, developers can unknowingly **break eager loading**. Let's explore common mistakes.

### **1. Calling `.order` After Preloading**
If you apply `order` after preloading, ActiveRecord **re-runs a new query**:

#### ❌ **Bad Practice:**
```ruby
Program.includes(:courses).each do |program|
  program.courses.order(:name).each do |course|
    puts course.name
  end
end
```

#### 🔍 **What Happens?**
- `includes(:courses)` loads all courses in one query.
- `.order(:name)` **invalidates** the preloaded records and **fires a new query** for each program!

#### ✅ **Solution:** Use `order` **before** loading:
```ruby
Program.includes(:courses).order("courses.name").each do |program|
  program.courses.each do |course|
    puts course.name
  end
end
```

---

### **2. Filtering Inside the Loop**
Another common issue is filtering associations inside a loop, which results in extra queries.

#### ❌ **Bad Practice:**
```ruby
Program.includes(:courses).each do |program|
  active_courses = program.courses.where(active: true) # This triggers a new query!
  active_courses.each { |course| puts course.name }
end
```

#### ✅ **Solution:** Preload with Conditions
```ruby
Program.joins(:courses).where(courses: { active: true }).each do |program|
  program.courses.each { |course| puts course.name }
end
```

---

### **3. Using `.pluck` Instead of `.map` on Preloaded Data**
Using `.pluck` on a preloaded association **bypasses** the already fetched data and **fires a new query**.

#### ❌ **Bad Practice:**
```ruby
programs = Program.includes(:courses)
programs.each do |program|
  course_names = program.courses.pluck(:name) # Triggers a new query!
end
```

#### ✅ **Solution:** Use `.map` Instead
```ruby
programs = Program.includes(:courses)
programs.each do |program|
  course_names = program.courses.map(&:name) # Uses in-memory data, no extra query
end
```

---

## **Best Practices for Preloading and Avoiding N+1**
✅ **Always check logs** (`rails console` or `bullet gem`) for unexpected queries.
✅ **Use `includes` or `preload`** for associations you will use.
✅ **Use `.order` before loading**, not inside loops.
✅ **Filter associations early** to avoid per-object queries.
✅ **Use `.map` instead of `.pluck`** when working with preloaded data.
✅ **Benchmark performance** with large datasets to ensure optimizations work.

---

## Conclusion
Eager loading with `includes` and `preload` is crucial for avoiding N+1 queries in Rails. However, minor mistakes—like ordering, filtering, or plucking incorrectly—can **silently** break preloading and lead to performance issues. By following best practices and being mindful of when and how queries execute, you can ensure your application runs efficiently and scales effectively.

🚀 **Happy coding, and may your queries be optimized!**


