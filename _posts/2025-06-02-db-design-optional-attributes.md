---
layout: post
title: "Designing a Schema for an Optional Attribute"
description: "A one-line feature request, recording why a student failed a course, walks through three schema options: a nullable column, a normalized table, and jsonb."
date: 2025-06-02T00:00:00-07:00
draft: false
tags: [database, postgresql, sql, architecture]
categories: [Database]
---

<audio controls preload="metadata" src="/assets/audio/db-design-optional-attributes-summary.ogg">
  Your browser does not support the audio element.
</audio>

A feature request arrives that sounds simple: "When a student fails a course, we need to record the reason why."

The instinct is to jump straight to `ALTER TABLE... ADD COLUMN...` and move on. But a database schema is the foundation of the application, and a crack in that foundation, however small, causes problems for years. This walks through a deliberate design process for that one-line request, not to find the single "right" answer, but to show how to ask the right questions before committing to a schema.

## Step 1: Deconstruct the Requirement

The initial requirement is the tip of the iceberg. The job is to find what's underneath it.

A few questions worth asking about the "fail reason" feature:

* **What is the *shape* of this data?** Is it just a simple text string (`"Did not submit final project"`), or could it be more structured? What if it's a `failure_type` from a dropdown, a final percentage score, and an optional text note?
* **Who provides this data?** Is it an instructor, an automated script, or an administrator? This might imply needing to store who recorded the reason and when.
* **How will we *use* this data?** Will we only ever look it up for a single student? Or will a future request be: "Show me a report of failure types across the entire university for the last semester."?
* **How common is this event?** The stakeholders mention it's rare, maybe only 1% of course enrollments end in failure. That detail matters.

A database design is only as good as the understanding behind it. A few minutes of questioning saves weeks of refactoring later. For this scenario, assume the failure reason might become more structured in the future, and that reporting on it is a real possibility.

## Step 2: The First Impulse, Just Add a Column

The most obvious solution is straightforward, fast, and gets the immediate job done.

**The Schema:**
```sql
ALTER TABLE user_course
ADD COLUMN fail_reason text NULL;
```

**The Analysis:**
This is the path of least resistance. It's incredibly simple to implement. The query to retrieve the reason is trivial. For the 1% of students who fail, it works perfectly.

But the questions from Step 1 should make us pause. This design immediately paints us into a corner.

* **The 99% Problem:** For the vast majority of your rows, this column will be `NULL`. While modern databases like PostgreSQL are very efficient at storing nulls, it feels... untidy. It's a field that simply doesn't apply to most of the entities in the table.
* **The Scalability Dead-End:** What happens when the request comes to add `failure_type` and `recorded_by_instructor_id`? Do we add more nullable columns? The `user_course` table gets wider and wider, cluttered with data that only applies to a fraction of its records.
* **The Reporting Nightmare:** Try writing an efficient query to count failure types when the type is just an unstructured text string. It’s messy and unreliable.

The simplest solution is often a short-term fix that accumulates design debt. It's a reasonable starting point for discussion, but not the final answer.

## Step 3: The Normalized Solution

If a "failure event" is its own distinct thing with its own attributes, give it its own table.

**The Schema:**
```sql
-- Main table stays clean
CREATE TABLE user_course (
    user_course_id serial PRIMARY KEY,
    user_id int,
    course_id int,
    status text -- 'enrolled', 'completed', 'failed'
);

-- New, dedicated table for the 1%
CREATE TABLE user_course_fail_details (
    user_course_id int PRIMARY KEY REFERENCES user_course(user_course_id),
    reason_text text,
    failure_type text, -- Can be an ENUM or foreign key
    recorded_by_id int REFERENCES instructors(instructor_id),
    timestamp timestamptz DEFAULT now()
);
```
**The Analysis:**
Look at how clean this is. Every piece of data is exactly where it belongs.

* **It's Scalable:** We can add as many details about the failure event as we want to the new table without ever touching the massive `user_course` table.
* **It's Efficient:** There are no wasted `NULL`s. Data is only stored when a failure actually occurs.
* **Data Integrity:** Foreign keys and `ENUM` types enforce correctness at the database level. Reporting on `failure_type` becomes trivial and fast.

The cost is a `LEFT JOIN` to get a complete picture of an enrollment. That's a small price for a design that stays clean, scalable, and correct as the schema grows. Normalization forces clear thinking about the entities in the system and how they relate.

## Step 4: The jsonb Compromise

A third path blends the single-table simplicity of the first option with the no-wasted-space benefit of normalization, using PostgreSQL's `jsonb` type.

**The Schema:**
```sql
CREATE TABLE user_course (
    user_course_id serial PRIMARY KEY,
    ...,
    status text,
    -- NULL for passes, a JSON object for other states
    status_details jsonb NULL
);
```
For a failure, the `status_details` column might contain:
`{"reason": "Did not submit project", "failure_type": "non-submission", "final_score": 45}`

For a withdrawal, it could be:
`{"reason": "Medical leave", "withdrew_on_date": "2025-05-10"}`

**The Analysis:**
This approach is powerful. It gives you immense flexibility to store different data shapes for different terminal states without touching your schema. It's a great fit if you have many such states (`failed`, `withdrew`, `incomplete`), each with its own unique descriptive data.

The flexibility comes at the cost of database-level integrity: there's no foreign key from `recorded_by_id` to the `instructors` table anymore, since it's just a key in a JSON blob, so validation shifts almost entirely to the application layer. `jsonb` is a compelling path when the primary need is flexibility for semi-structured data, but it requires discipline where the database used to enforce it for you.

## Making the Final Decision

Back to the questions from Step 1:

* If the business is certain the fail reason will always be a single text field, the plain column (Step 2) is a pragmatic, if impure, choice.
* If there are many different states with unpredictable, varied data, `jsonb` (Step 4) is a strong contender.
* If a failure is a critical event with structured data that needs reporting and integrity guarantees, the normalized table (Step 3) is the more professional choice.

For student records, where scalability and data integrity matter, the normalized, separate table is the one most likely to hold up over time.

The real work happens before the migration file exists: questioning the requirement, weighing the trade-offs, and resisting the urge to implement whatever comes to mind first. A "simple" feature request is usually an opportunity to think it through, not just a task to close.
