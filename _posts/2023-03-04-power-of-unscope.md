---
layout: post
title: Power of unscope
date: 2023-03-04 00:00 +0000
categories: Rails
---
# The Power of Unscope in Ruby on Rails

In Ruby on Rails, scopes are a convenient way to encapsulate common query patterns, making it easier to write clean and reusable code. However, there are times when you might need to deviate from these patterns, and that's where the `unscope` method comes in.

## Understanding `unscope`

The `unscope` method allows you to selectively remove certain scopes from your ActiveRecord queries. This can be useful when you need to perform a query that doesn't conform to your usual patterns or when you need to override a default scope.

### Default Scope Example

Consider a `Post` model with a default scope:

```ruby
class Post
  default_scope { where(deleted_at: nil).where.not(published_at: nil).order(published_at: :desc) }
end
```

This default scope ensures that only posts that have not been deleted and have been published are retrieved, and they are ordered by the `published_at` date in descending order.

### Using `unscope`

Let's explore how `unscope` can be used to modify or completely remove these default scopes:

```ruby
# Show all the posts, including the ones that have been deleted
Post.unscoped
```

This retrieves all posts, regardless of their `deleted_at` or `published_at` status.

```ruby
# Show all the posts without considering the default where conditions
Post.unscope(where: :deleted_at)
```

This removes the `deleted_at` condition from the scope.

```ruby
# Show all the posts without considering the order condition
Post.unscope(order: :published_at)
```

This removes the ordering condition from the scope.

```ruby
# Remove both where and order conditions
Post.unscope(where: [:deleted_at, :published_at], order: :published_at)
```

This completely removes both the `where` conditions and the `order` from the default scope.

### Similar Features

Rails provides several other methods that can be used in conjunction with or as alternatives to `unscope`:

1. **`unscoped`**: This is an alias for `all` and removes all scopes, including default scopes, from the query.

2. **`with`**: This method allows you to define a new scope that can be used in place of the default scope.

3. **`merge`**: This method can be used to merge a new scope with an existing scope.

4. **`only`**: This method is used to specify only certain columns to be retrieved from the database.

### Practical Examples

Here's how you can use `only`, `with`, and `merge`:

```ruby
# Select only specific columns
Post.select(:title, :content).only(:select)
# discards the order condition
Post.order('id asc').only(:where)
# uses the specified order
Post.order('id asc').only(:where, :order)

# Define a new scope with 'with'
class Post < ApplicationRecord
  with :recent, :published

  private

  def self.recent
    where('created_at > ?', 1.week.ago)
  end

  def self.published
    where.not(published_at: nil)
  end
end

# Retrieve the 10 most recent published posts
Post.recent.published.limit(10)

# Merge two scopes
Post.where(:published).merge(Post.order(:title))
```

### Careful Considerations

- **Performance**: Using `unscope` can lead to performance issues if not used carefully, especially when removing default scopes that are designed to filter large datasets.
- **Readability**: While `unscope` can make your code more flexible, it can also make it harder to read and understand, especially for developers who are not familiar with the default scopes.
- **Testing**: When using `unscope`, it's important to ensure that your tests cover the scenarios where the default scopes are bypassed to prevent unexpected behavior in production.
- **Merging**: When merging scopes, be aware that certain keys will be overwritten, while `where` and `include` will be merged. This can lead to complex query logic if not managed properly.

### Conclusion

The `unscope` method is a powerful tool in Ruby on Rails that allows developers to have granular control over their queries. It's especially useful when you need to perform operations that don't align with your predefined scopes. By understanding and utilizing `unscope`, along with `only`, `with`, and `merge`, you can write more flexible and dynamic queries in your Rails applications.

Remember, while these methods provide flexibility, it's important to use them judiciously to maintain the integrity and consistency of your application's data handling.
