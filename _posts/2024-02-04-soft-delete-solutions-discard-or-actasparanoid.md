---
layout: post
title: 'Soft Delete Solutions: Discard or ActAsParanoid?'
date: 2024-02-04 00:00 +0000
---
# Soft Delete Solutions: Discard or ActAsParanoid?

## Explain What is Soft Delete and Why It is Used a Lot

Soft delete, also known as logical delete, is a data management strategy that allows for the preservation of data in a database while marking it as "deleted" to the application. This is achieved by adding a flag or timestamp column (such as `deleted_at` or `is_deleted`) to the database table. When a record is soft deleted, it is not actually removed from the database; instead, it is hidden from regular queries but can still be accessed and restored if necessary. Soft delete is widely used for several reasons:

1. **Data Recovery**: It allows for the recovery of data in case of accidental deletion.
2. **Audit Trails**: It helps maintain a history of changes for compliance and auditing purposes.
3. **Data Integrity**: It preserves foreign key relationships and avoids orphan records.

## Explain the Implementations: Discard and ActAsParanoid

### Discard
Discard is a Ruby on Rails gem that facilitates soft deleting by adding a `discarded_at` column to the model. When a record is discarded, this column is set to the current time, effectively hiding the record from standard queries. To restore a discarded record, the `undiscard` method is used. Discard also respects `dependent: :destroy` associations, ensuring that associated records are softly deleted as well.

### ActAsParanoid
ActAsParanoid is another Rails plugin that implements soft deletes by adding a `deleted_at` column. When a record is marked for destruction, ActAsParanoid sets the `deleted_at` field to the current time instead of removing the record from the database. To permanently delete a record, the `really_destroy!` method is used, which bypasses the soft delete logic.

## Explain the Idea Behind the Design

The design behind soft delete implementations like Discard and ActAsParanoid is to provide a safety net against accidental data loss while maintaining the appearance of a clean database state to the application. By keeping the data in the database but marking it as deleted, developers can recover data if needed and ensure that the application's data integrity is not compromised.

## Developer's Concerns

### Hide Information from the Developer
One of the concerns with using soft delete gems like Discard is that they can hide the actual state of the data from the developer. For example, a command like `User.delete_all` does not actually delete all records but marks them as discarded, which can lead to confusion.

### Incorrect Use of Unscoped
Another concern is the improper use of the `unscoped` method. `Unscoped` is intended to temporarily remove all scoped conditions, but if not used correctly, it can lead to the loss of intended filtering, such as `User.where.not(address: nil).unscoped.first.address`, which might return a record that should have been excluded.

## Discuss the Trade-offs When Using Such Gems and Why Need to Be Very Careful

When using soft delete gems like Discard or ActAsParanoid, there are several trade-offs to consider:

1. **Performance Overhead**: Soft deletes can introduce performance overhead due to the need for additional columns and conditions in queries to filter out soft-deleted records.
2. **Increased Complexity**: The use of soft deletes adds complexity to the application, as developers must remember to account for soft-deleted records in their queries and logic.
3. **Data Bloat**: Over time, soft-deleted records can accumulate, leading to data bloat and potentially affecting database performance.

Developers need to be very careful when using such gems to ensure that they understand the implications of soft deletes on their application's data management and performance. It is also important to have clear guidelines and tests in place to ensure that soft deletes are used correctly and do not lead to unintended data loss or integrity issues.

