---
layout: post
title: "Migrating from Kaminari to will_paginate in Rails"
description: "A step-by-step guide to migrating a Rails app's pagination from Kaminari to will_paginate, covering models, controllers, views, and API responses."
date: 2024-10-20 10:00 +0000
categories: [Rails]
tags: [kaminari, will_paginate, rails, pagination]
---

<audio controls preload="metadata" src="/assets/audio/migrate-kaminari-to-will-paginate-summary.ogg">
  Your browser does not support the audio element.
</audio>


Pagination breaks large datasets into manageable chunks, and both Kaminari and will_paginate do that job well for Rails. Migrating from one to the other touches models, controllers, views, and anywhere pagination metadata gets serialized into an API response. Here's the full path.

## Basic setup

Replace Kaminari with will_paginate in the Gemfile:

```ruby
# Gemfile
# Remove or comment out
# gem 'kaminari'

# Add will_paginate
gem 'will_paginate'
# Optional: Add Bootstrap styling
gem 'will_paginate-bootstrap-style' # if using Bootstrap
```

```bash
bundle install
```

## Model changes

### Basic pagination configuration

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

### Maximum page size limits

Kaminari's `max_paginates_per` has no direct equivalent in will_paginate; a small concern reproduces it:

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

## Controller updates

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

For paginating a plain array:

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

## View modifications

```erb
<%# Before (Kaminari) %>
<%= paginate @posts %>

<%# After (will_paginate) %>
<%= will_paginate @posts %>
```

A custom Kaminari template needs a matching will_paginate renderer. Here's a Bootstrap-style example:

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

```slim
= will_paginate @collection,
  renderer: CustomPaginationRenderer,
  previous_label: t('views.pagination.previous'),
  next_label: t('views.pagination.next'),
  inner_window: 2,
  outer_window: 1
```

## API response adjustments

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

## Handling advanced features

### AJAX pagination

```javascript
// Using jQuery
$(document).on('click', '.pagination a', function(e) {
  e.preventDefault();
  $.get(this.href, function(data) {
    $('#content').html(data);
  });
});
```

### Infinite scrolling

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

## Common challenges

### Handling empty collections

```ruby
# Before (Kaminari)
@empty = Model.none.page(1)
@empty.total_count # => 0

# After (will_paginate)
@empty = Model.none.paginate(page: 1)
@empty.total_entries # => 0
```

## Testing considerations

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

## Method names differ throughout

```
# Kaminari          # will_paginate
total_count         total_entries
num_pages           total_pages
prev_page           previous_page
limit_value         per_page
```

Chase down every occurrence of these before considering the migration done; they're the failures that don't show up until a page renders one count short or a spec compares against a method that no longer exists.
