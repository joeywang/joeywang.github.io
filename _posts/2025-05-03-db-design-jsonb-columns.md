---
layout: post
title: "PostgreSQL JSONB vs Linking Tables for Relationships"
description: "Comparing PostgreSQL jsonb columns against a traditional linking table for modeling course prerequisites, and where a hybrid of both makes more sense."
date: 2025-05-03T00:00:00-07:00
categories: [Database]
tags: [postgresql, database, performance]
---

<audio controls preload="metadata" src="/assets/audio/db-design-jsonb-columns-summary.ogg">
  Your browser does not support the audio element.
</audio>

Relational purity or `jsonb` flexibility: it's a real design decision, and a concrete example makes the trade-offs clearer than the abstract debate does.

## The problem: linking courses without repetition

A learning platform has courses made of lessons. "Advanced SQL" requires "Beginner SQL": before a student enrolls in the advanced course, the platform needs to know every lesson from its prerequisites, so it doesn't re-enroll them in material they've already covered. How do you model that `requires` relationship?

## Path 1: jsonb

Add a `jsonb` column to `courses` and embed the relationship directly:

```sql
CREATE TABLE courses (
    course_id serial PRIMARY KEY,
    course_title text NOT NULL,
    journey_details jsonb
);

INSERT INTO courses (course_id, course_title, journey_details) VALUES
(101, 'Beginner SQL', NULL),
(102, 'Advanced SQL', '{"prerequisites": [101]}'),
(103, 'SQL for Data Science', '{"prerequisites": [101, 102], "recommended": [201]}');
```

The third row adds a "recommended" relationship, a type that didn't exist a moment ago, with no `ALTER TABLE`. Querying it means un-nesting the array:

```sql
SELECT DISTINCT lesson.lesson_title
FROM lessons
JOIN course_lessons ON lesson.lesson_id = course_lessons.lesson_id
WHERE course_lessons.course_id IN (
    SELECT jsonb_array_elements_text(journey_details -> 'prerequisites')::int
    FROM courses
    WHERE course_id = 103
);
```

It works. Whether it stays correct as the data grows is a different question.

## Path 2: a linking table

The textbook, third-normal-form approach:

```sql
CREATE TABLE course_prerequisites (
    course_id int REFERENCES courses(course_id) ON DELETE CASCADE,
    prerequisite_id int REFERENCES courses(course_id) ON DELETE CASCADE,
    PRIMARY KEY (course_id, prerequisite_id)
);

INSERT INTO course_prerequisites (course_id, prerequisite_id) VALUES
(102, 101),
(103, 101),
(103, 102);
```

The `FOREIGN KEY` constraints make it impossible to link to a course that doesn't exist. The query is a plain `JOIN`:

```sql
SELECT DISTINCT lesson.lesson_title
FROM lessons
JOIN course_lessons ON lesson.lesson_id = course_lessons.lesson_id
JOIN course_prerequisites cp ON course_lessons.course_id = cp.prerequisite_id
WHERE cp.course_id = 103;
```

## The trade-offs

| Consideration | jsonb | Linking table |
| :--- | :--- | :--- |
| **Data integrity** | Nothing stops a prerequisite ID that points to nothing; validation is entirely the application's job. | The database rejects a bad reference at insert time; `ON DELETE CASCADE` handles cleanup automatically. |
| **Flexibility** | Add a new relationship type by adding a JSON key. No migration. | A new relationship type means an `ALTER TABLE` and a deliberate migration. |
| **Maintainability** | Deleting a course means hunting down every `jsonb` column that might reference it. | Deleting a course cascades through the constraint automatically. |
| **Performance** | Fast with a GIN index; `jsonb` is not inherently slow. | Fast with an indexed foreign key; this is what relational databases are built for. |

Performance is close to a wash either way. The real question is who's responsible for the data's correctness: the application, or the database.

## The pragmatic answer

Use a linking table for the relationship that's actually business-critical, the one where a dangling reference is a real bug. Use a `jsonb` column for the soft, descriptive data around it: recommendations, notes, anything that's genuinely schema-less and doesn't need referential integrity. `course_prerequisites` stays a real table; a `course_metadata` jsonb column can hold everything else.

The deciding question isn't "which is faster," it's "is this a rule or a suggestion." Rules belong in constraints. Suggestions can live in JSON.
