---
layout: post
title: 'Soft Delete Solutions: Discard or ActAsParanoid?'
date: 2024-02-04 00:00 +0000
---
# Soft Delete Solutions: Discard or ActAsParanoid?

## What is Soft Delete and Why It is Used a Lot

Soft delete, also known as logical delete, is a data management strategy that allows for the preservation of data in a database while marking it as "deleted" to the application. This is achieved by adding a flag or timestamp column (such as `deleted_at` or `is_deleted`) to the database table. When a record is soft deleted, it is not actually removed from the database; instead, it is hidden from regular queries but can still be accessed and restored if necessary.

Soft delete is widely used for several reasons:

1. **Data Recovery**: It allows for the recovery of data in case of accidental deletion or if the information needs to be reinstated.
2. **Audit Trails**: It helps maintain a history of changes for compliance and auditing purposes, providing a clear record of when data was "deleted" and potentially by whom.
3. **Data Integrity**: It preserves foreign key relationships and avoids orphan records, ensuring that related data remains consistent.
4. **Legal and Regulatory Compliance**: In some industries, retaining data for a certain period is mandatory, even after it's no longer actively used.
5. **User Experience**: It allows for features like "trash" or "recycle bin" in applications, giving users the ability to restore their own deleted data.

## Implementations: Discard and ActAsParanoid

### Discard

Discard is a Ruby on Rails gem that facilitates soft deleting by adding a `discarded_at` column to the model. Key features include:

- When a record is discarded, the `discarded_at` column is set to the current time, effectively hiding the record from standard queries.
- To restore a discarded record, the `undiscard` method is used.
- Discard respects `dependent: :destroy` associations, ensuring that associated records are softly deleted as well.
- It provides scopes like `kept` and `discarded` for easy filtering of records.
- Discard can be configured to use callbacks, allowing custom logic to be executed before or after discard/undiscard operations.

Example usage:
```ruby
class User < ApplicationRecord
  include Discard::Model
  has_many :posts, dependent: :destroy
end

user = User.create(name: "John")
user.discard  # Sets discarded_at to current time
user.discarded?  # Returns true
User.kept  # Returns all non-discarded users
user.undiscard  # Restores the user
```

### ActAsParanoid

ActAsParanoid is another Rails plugin that implements soft deletes by adding a `deleted_at` column. Its features include:

- When a record is marked for destruction, ActAsParanoid sets the `deleted_at` field to the current time instead of removing the record from the database.
- To permanently delete a record, the `really_destroy!` method is used, which bypasses the soft delete logic.
- It provides methods like `only_deleted` and `with_deleted` for querying soft-deleted records.
- ActAsParanoid can be configured to use a boolean flag instead of a timestamp for marking deleted records.
- It supports custom column names and can handle multiple paranoid columns.

Example usage:
```ruby
class Post < ActiveRecord::Base
  acts_as_paranoid
end

post = Post.create(title: "Hello")
post.destroy  # Sets deleted_at to current time
Post.only_deleted  # Returns only soft-deleted posts
post.recover  # Restores the post
post.really_destroy!  # Permanently deletes the post
```

## Idea Behind the Design

The design behind soft delete implementations like Discard and ActAsParanoid is to provide a safety net against accidental data loss while maintaining the appearance of a clean database state to the application. By keeping the data in the database but marking it as deleted, developers can:

1. Recover data if needed, reducing the risk of permanent data loss.
2. Maintain data integrity by preserving relationships between records.
3. Implement features like "undo" or "restore" in their applications.
4. Meet regulatory requirements for data retention.
5. Improve query performance by not having to check for orphaned records.

## Developer's Concerns

### Hide Information from the Developer

One of the concerns with using soft delete gems is that they can hide the actual state of the data from the developer. This can lead to several issues:

1. Misunderstanding of data volume: Developers might underestimate the amount of data in the database if they don't account for soft-deleted records.
2. Unexpected query results: Commands like `User.delete_all` do not actually delete all records but mark them as discarded, which can lead to confusion.
3. Complexity in data management: Developers need to be aware of the soft delete mechanism and adjust their queries and data handling accordingly.

### Incorrect Use of Unscoped

Another concern is the improper use of the `unscoped` method. `Unscoped` is intended to temporarily remove all scoped conditions, but if not used correctly, it can lead to unintended consequences:

1. Loss of intended filtering: For example, `User.where.not(address: nil).unscoped.first.address` might return a record that should have been excluded.
2. Performance issues: Removing all scopes can lead to unnecessarily large result sets.
3. Security risks: Unscoped queries might expose soft-deleted data that should remain hidden.

## Trade-offs When Using Such Gems and Why Need to Be Very Careful

When using soft delete gems like Discard or ActAsParanoid, there are several trade-offs to consider:

1. **Performance Overhead**:
   - Soft deletes can introduce performance overhead due to the need for additional columns and conditions in queries to filter out soft-deleted records.
   - Indexes may need to be adjusted to maintain query performance.

2. **Increased Complexity**:
   - The use of soft deletes adds complexity to the application, as developers must remember to account for soft-deleted records in their queries and logic.
   - It can complicate data migrations and schema changes.

3. **Data Bloat**:
   - Over time, soft-deleted records can accumulate, leading to data bloat and potentially affecting database performance.
   - This may necessitate periodic purging of old soft-deleted records.

4. **Consistency Challenges**:
   - Ensuring consistent behavior across all parts of the application, including third-party integrations, can be challenging.

5. **Potential for Data Leaks**:
   - If not properly managed, soft-deleted data might be accidentally exposed or included in reports.

Developers need to be very careful when using such gems to ensure that they:

1. Understand the implications of soft deletes on their application's data management and performance.
2. Have clear guidelines and tests in place to ensure that soft deletes are used correctly and do not lead to unintended data loss or integrity issues.
3. Implement proper access controls to prevent unauthorized access to soft-deleted data.
4. Consider the long-term impact on database size and performance, and plan for data archiving or permanent deletion strategies.
5. Educate all team members about the use of soft deletes to prevent misunderstandings and incorrect data handling.

By carefully considering these factors and implementing soft delete mechanisms thoughtfully, developers can leverage the benefits of data preservation while mitigating the potential drawbacks and risks associated with soft delete solutions.
