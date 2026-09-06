---
layout: post
title: "User Impersonation in Rails with the Pretender Gem"
date: 2025-06-02
tags: [rails, security, debugging]
categories: [Rails, Security]
description: "User impersonation lets an admin temporarily act as another user for debugging and support, and the pretender gem handles the current_user switch and session state."
---

<audio controls preload="metadata" src="/assets/audio/user-impersonation-summary.ogg">
  Your browser does not support the audio element.
</audio>

User impersonation lets a privileged user, typically an admin, temporarily act as another user inside the application. It sounds like it should be complicated, but the underlying mechanism is small: it changes what the application treats as `current_user`.

## Why You'd Need This

It's not something every app needs, but it earns its place in a few scenarios:

1. **Debugging and support:** when a user reports a bug you can't reproduce, impersonation lets you see the application exactly as they do.
2. **Testing:** switching between user roles (standard, premium, new signup) without logging in and out repeatedly.
3. **Auditing and compliance:** verifying a user's view of certain data for compliance reasons, handled with logging and care.

## What Actually Changes

If you're using a common setup like Devise, you have a `current_user` helper available everywhere. Impersonation swaps what `current_user` returns to the impersonated user, while keeping track of who the original admin was.

## The `pretender` Gem

You could build this from scratch, but `pretender` is a small, well-maintained gem that handles the underlying session mechanics.

### Step 1: Add the Gem

Add `pretender` to your `Gemfile`:

```ruby
# Gemfile

gem 'pretender'
```

Then run `bundle install`.

### Step 2: Enable It on ApplicationController

Tell `ApplicationController` that it handles impersonation by adding `impersonates :user` (assuming your user model is `User`):

```ruby
# app/controllers/application_controller.rb
class ApplicationController < ActionController::Base
  impersonates :user # Or whatever your main user model is, e.g., :admin_user

  # ... your existing authentication methods, e.g., current_user, authenticate_user!
end
```

That line gives you `impersonate_user(user_instance)` and `stop_impersonating_user`.

### Step 3: Controller Actions

These actions belong in a controller only accessible to privileged users, for example `Admin::UsersController`, which already lists all users.

```ruby
# app/controllers/admin/users_controller.rb
class Admin::UsersController < ApplicationController
  before_action :authenticate_admin! # Make sure only admins can access these actions!

  def index
    @users = User.order(:email)
  end

  def impersonate
    user_to_impersonate = User.find(params[:id])
    impersonate_user(user_to_impersonate) # This is where pretender shines!
    redirect_to root_path, notice: "You are now impersonating #{user_to_impersonate.email}."
  rescue ActiveRecord::RecordNotFound
    redirect_to admin_users_path, alert: "User not found."
  end

  def stop_impersonating
    stop_impersonating_user # And this is how you go back to being yourself.
    redirect_to admin_users_path, notice: "You have stopped impersonating."
  end

  private

  def authenticate_admin!
    # Implement your admin authorization here.
    # For example, if using Devise with an `admin` boolean column:
    # unless current_user&.admin?
    #   redirect_to root_path, alert: "You are not authorized to view this page."
    # end
  end
end
```

### Step 4: Routes

Add routes for these actions:

```ruby
# config/routes.rb
Rails.application.routes.draw do
  namespace :admin do
    resources :users, only: [:index] do
      post :impersonate, on: :member # For /admin/users/:id/impersonate
      post :stop_impersonating, on: :collection # For /admin/users/stop_impersonating
    end
  end

  # ... your other routes
end
```

Note `on: :member` for impersonating a specific user and `on: :collection` for the general "stop" action.

### Step 5: Make the State Visible

The admin needs to know who they are and who they're currently impersonating, at all times, in the UI.

In the admin users list (`app/views/admin/users/index.html.erb`):

```erb
<h1>Admin User Management</h1>

<% if current_user && true_user && current_user != true_user %>
  <div style="background-color: #fffacd; padding: 10px; border-left: 5px solid #ffeb3b; margin-bottom: 20px;">
    <strong>Heads Up!</strong> You (<%= true_user.email %>) are currently viewing the app as <%= current_user.email %>.
    <%= button_to "Stop Impersonating", stop_impersonating_admin_users_path, method: :post, data: { turbo: false, confirm: "Are you sure you want to stop impersonating?" }, class: "btn btn-sm btn-warning ms-3" %>
  </div>
<% end %>

<table>
  <thead>
    <tr>
      <th>Email</th>
      <th>Actions</th>
    </tr>
  </thead>
  <tbody>
    <% @users.each do |user| %>
      <tr>
        <td><%= user.email %></td>
        <td>
          <% if user == current_user %>
            <span class="badge bg-secondary">Current User (You)</span>
          <% else %>
            <%= button_to "Impersonate", impersonate_admin_user_path(user), method: :post, data: { turbo: false }, class: "btn btn-sm btn-primary" %>
          <% end %>
        </td>
      </tr>
    <% end %>
  </tbody>
</table>
```

Note the `data: { turbo: false }` on the `button_to` tags. Forms that change session state need a full page reload, since Turbo's caching can otherwise leave stale state in the impersonation banner.

In the main layout (`app/views/layouts/application.html.erb`), add the same indicator globally:

```erb
<!DOCTYPE html>
<html>
<head>
  <title>My Awesome App</title>
  <%= csrf_meta_tags %>
  <%= csp_meta_tag %>
  <%= stylesheet_link_tag 'application', media: 'all', 'data-turbo-track': 'reload' %>
  <%= javascript_importmap_tags %>
</head>
<body>
  <% if current_user && true_user && current_user != true_user %>
    <div style="background-color: #f8d7da; color: #721c24; padding: 10px; text-align: center; border-bottom: 1px solid #f5c6cb;">
      <i class="fas fa-exclamation-triangle"></i>
      <strong>IMPERSONATION MODE:</strong> You are currently logged in as **<%= current_user.email %>**.
      <%= link_to "Stop Impersonating", stop_impersonating_admin_users_path, data: { turbo_method: :post, turbo_confirm: "Are you sure you want to stop impersonating?" }, style: "color: #721c24; text-decoration: underline; margin-left: 15px;" %>
    </div>
  <% end %>

  <%= yield %>
</body>
</html>
```

A banner that's easy to miss defeats the purpose. Make it visually unmissable.

## How `pretender` Works Under the Hood

The `impersonates :user` line augments `current_user`. Calling `impersonate_user(some_user)` stores the original admin's ID in the session (typically `session[:true_user_id]`) and changes what `current_user` returns to the impersonated user. `true_user` gives you the original administrator's object at any point. `stop_impersonating_user` clears that session variable and `current_user` reverts.

## Security Notes

* **Strict authorization:** only trusted admins or support staff should reach these actions. Check the `before_action` filters carefully.
* **Logging:** log every impersonation event in production, who impersonated whom, when it started, and when it stopped. This is what makes it auditable rather than a backdoor.
* **No password access:** impersonation should never expose or let an admin change a user's actual password. It's for viewing, not for taking over the account.
* **Session management:** if you're not using `pretender`, be careful how `true_user` and `impersonated_user` IDs are managed in the session.
* **Action Cable:** if you use real-time features, verify that `current_user` context carries over correctly into your Action Cable channels; `pretender` handles this well by default.

Impersonation is a genuinely useful addition to a Rails admin toolkit for debugging, support, and testing. The gem handles the mechanics; the security discipline around logging, authorization, and UI visibility is still on you.
