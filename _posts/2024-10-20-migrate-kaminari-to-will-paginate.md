---
layout: post
title: "Migrating from Kaminari to will_paginate in Rails: A Complete Guide"
date: 2024-10-20 10:00 +0000
tags: ["kaminari", "will_paginate", "rails", "pagination"]
---

# Migrating from Kaminari to will_paginate in Rails: A Complete Guide

Pagination is a crucial feature in web applications, helping manage large datasets by breaking them into manageable chunks. While both Kaminari and will_paginate are excellent pagination libraries for Rails, you might find yourself needing to migrate from one to the other. This guide walks through the complete process of migrating from Kaminari to will_paginate, covering all aspects from basic setup to handling complex scenarios.

## Table of Contents
1. [Basic Setup](#basic-setup)
2. [Model Changes](#model-changes)
3. [Controller Updates](#controller-updates)
4. [View Modifications](#view-modifications)
5. [API Response Adjustments](#api-response-adjustments)
6. [Handling Advanced Features](#handling-advanced-features)
7. [Common Challenges](#common-challenges)
8. [Testing Considerations](#testing-considerations)

## Basic Setup

First, update your Gemfile by replacing Kaminari with will_paginate:

```ruby
# Gemfile
# Remove or comment out
# gem 'kaminari'

# Add will_paginate
gem 'will_paginate'
# Optional: Add Bootstrap styling
gem 'will_paginate-bootstrap-style' # if using Bootstrap
```

Run bundle to install the new gem:

```bash
bundle install
```

## Model Changes

### Basic Pagination Configuration

Kaminari and will_paginate have different approaches to configuring pagination defaults. Here's how to migrate:

```ruby
# Before (Kaminari)
class Post < ApplicationRecord
  paginates_per 25
end

# After (will_paginate)
class Post < ApplicationRecord
  self.per_page = 25
end
```

### Maximum Page Size Limits

Kaminari's `max_paginates_per` doesn't have a direct equivalent in will_paginate. Here's how to implement it:

```ruby
# app/models/concerns/pagination_limiter.rb
module PaginationLimiter
  extend ActiveSupport::Concern

  class_methods do
    def max_per_page
      @max_per_page ||= 100
    end

    def max_per_page=(value)
      @max_per_page = value
    end
  end

  included do
    def self.paginate(options = {})
      options[:per_page] = [
        options.fetch(:per_page, self.per_page).to_i,
        max_per_page
      ].min

      super(options)
    end
  end
end

# In your model
class Post < ApplicationRecord
  include PaginationLimiter

  self.max_per_page = 50
  self.per_page = 25
end
```

## Controller Updates

Update your controller pagination calls:

```ruby
# Before (Kaminari)
def index
  @posts = Post.page(params[:page]).per(25)
end

# After (will_paginate)
def index
  @posts = Post.paginate(page: params[:page], per_page: 25)
end
```

For more complex scenarios, like handling collections:

```ruby
# Before (Kaminari)
@array = Kaminari.paginate_array(my_array).page(params[:page]).per(25)

# After (will_paginate)
@array = WillPaginate::Collection.create(params[:page] || 1, 25) do |pager|
  result = my_array[pager.offset, pager.per_page] || []
  pager.replace(result)
  pager.total_entries = my_array.length
end
```

## View Modifications

### Basic Pagination Links

The simplest change is updating your view helpers:

```erb
<%# Before (Kaminari) %>
<%= paginate @posts %>

<%# After (will_paginate) %>
<%= will_paginate @posts %>
```

### Custom Pagination Template

If you have custom Kaminari templates, you'll need to create a custom renderer for will_paginate. Here's how to migrate a Bootstrap-style paginator:

```ruby
# app/lib/custom_pagination_renderer.rb
class CustomPaginationRenderer < WillPaginate::ActionView::LinkRenderer
  def container_attributes
    {class: 'pagination'}
  end

  def page_number(page)
    if page == current_page
      tag(:li, tag(:span, page, class: 'page-link'), class: 'page-item active')
    else
      tag(:li, link(page, page, class: 'page-link'), class: 'page-item')
    end
  end

  def previous_page
    num = @collection.current_page > 1 && @collection.current_page - 1
    previous_or_next_page(num, @options[:previous_label], 'prev')
  end

  def next_page
    num = @collection.current_page < total_pages && @collection.current_page + 1
    previous_or_next_page(num, @options[:next_label], 'next')
  end

  def gap
    tag(:li, tag(:span, '&hellip;'.html_safe, class: 'page-link'), class: 'page-item gap disabled')
  end

  protected

  def previous_or_next_page(page, text, classname)
    if page
      tag(:li, link(text, page, class: 'page-link'), class: "page-item #{classname}")
    else
      tag(:li, tag(:span, text, class: 'page-link'), class: "page-item #{classname} disabled")
    end
  end
end
```

Use the custom renderer in your views:

```slim
= will_paginate @collection,
  renderer: CustomPaginationRenderer,
  previous_label: t('views.pagination.previous'),
  next_label: t('views.pagination.next'),
  inner_window: 2,
  outer_window: 1
```

## API Response Adjustments

When using pagination in API responses, you'll need to update your pagination metadata:

```ruby
# Before (Kaminari)
def pagination_metadata(collection)
  {
    current_page: collection.current_page,
    total_pages: collection.total_pages,
    total_count: collection.total_count,
    next_page: collection.next_page,
    prev_page: collection.prev_page
  }
end

# After (will_paginate)
def pagination_metadata(collection)
  {
    current_page: collection.current_page,
    total_pages: collection.total_pages,
    total_entries: collection.total_entries,
    next_page: collection.next_page,
    previous_page: collection.previous_page
  }
end
```

## Handling Advanced Features

### AJAX Pagination

Update your JavaScript handlers:

```javascript
// Using jQuery
$(document).on('click', '.pagination a', function(e) {
  e.preventDefault();
  $.get(this.href, function(data) {
    $('#content').html(data);
  });
});
```

### Infinite Scrolling

Adjust your infinite scrolling implementation:

```ruby
# Controller
def index
  @posts = Post.paginate(page: params[:page])
  respond_to do |format|
    format.html
    format.js
  end
end
```

```javascript
// app/javascript/infinite_scroll.js
document.addEventListener('scroll', function() {
  if (nearBottom() && !loading) {
    loading = true;
    const nextPage = parseInt($('.pagination .next_page').attr('href').match(/page=(\d+)/)[1]);

    fetch(`${window.location.pathname}?page=${nextPage}`, {
      headers: {
        'Accept': 'text/javascript'
      }
    })
    .then(response => response.text())
    .then(html => {
      document.querySelector('#content').insertAdjacentHTML('beforeend', html);
      loading = false;
    });
  }
});
```

## Common Challenges

### Method Name Differences

Be aware of these key method name changes:

```ruby
# Kaminari          # will_paginate
total_count         total_entries
num_pages           total_pages
prev_page           previous_page
limit_value        per_page
```

### Handling Empty Collections

will_paginate handles empty collections differently:

```ruby
# Before (Kaminari)
@empty = Model.none.page(1)
@empty.total_count # => 0

# After (will_paginate)
@empty = Model.none.paginate(page: 1)
@empty.total_entries # => 0
```

## Testing Considerations

Update your test helpers and expectations:

```ruby
# spec/support/pagination_helper.rb
module PaginationHelper
  def expect_pagination(collection, options = {})
    expect(collection).to respond_to(:total_entries)
    expect(collection).to respond_to(:current_page)
    expect(collection.current_page).to eq(options[:page] || 1)
    expect(collection.per_page).to eq(options[:per_page] || 25)
  end
end

# In your tests
RSpec.describe PostsController, type: :controller do
  include PaginationHelper

  it "paginates the posts" do
    get :index, params: { page: 2, per_page: 10 }
    expect_pagination(assigns(:posts), page: 2, per_page: 10)
  end
end
```

## Conclusion

Migrating from Kaminari to will_paginate requires careful attention to detail, but the process is straightforward if you follow these steps. Remember to:

1. Update all pagination calls in your models and controllers
2. Migrate any custom templates to will_paginate's renderer system
3. Update your tests to use will_paginate's methods
4. Test thoroughly, especially edge cases and custom implementations

By following this guide, you should be able to successfully migrate your Rails application from Kaminari to will_paginate while maintaining all your pagination functionality.
