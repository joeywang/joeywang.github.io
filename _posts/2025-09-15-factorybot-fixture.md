---
title: "Why Using Business Logic for Test Setup Is a Rails Antipattern"
description: "Using application services to build test data couples your specs to that business logic, making test suites slow and fragile; Factory Bot traits fix it."
date: 2025-09-15
tags: [rails, testing, ruby]
categories: [Rails]
---

<audio controls preload="metadata" src="/assets/audio/factorybot-fixture-summary.ogg">
  Your browser does not support the audio element.
</audio>

Faced with complex model relationships and validations, many Rails developers default to using their application's services or commands, the actual business logic, to create test setup data. This is an antipattern. It couples your test data setup to your application's logic, and that produces slow, fragile, high-maintenance test suites.

The fix is Factory Bot: it separates the fast creation of necessary state from the slow execution of complex logic.

-----

## I. The Problem: The Temptation and the Speed Killer

When a model requires multiple associated records or complex initial state, it's tempting to use the code that guarantees a valid object:

```ruby
# 🚩 THE ANTIPATTERN (Slow Setup)
# Uses the full application business logic to create data
RSpec.describe PostPolicy do
  it "allows a premium user to view a draft post" do
    # 1. This service runs validations, callbacks, creates associations, 
    #    potentially sends emails, and uses database transactions.
    user = User::RegistrationService.call(email: "test@example.com", role: :premium)
    post = Post::CreationService.call(user: user, title: "Draft", status: :draft)

    # 2. Only now does the test actually start.
    expect(described_class).to permit(user, post)
  end
end
```

### The Consequences of Slow Setup

| Con | Description |
| :--- | :--- |
| **Slow execution** | Services often run database transactions, complex validations, and `after_create` callbacks (API calls, caching, sending emails). Running that logic before every test adds real overhead. |
| **Test fragility** | If `User::RegistrationService` changes, say it requires a new parameter, dozens of unrelated tests break. You end up fixing setup code, not feature code. |
| **Lack of isolation** | The test implicitly relies on and executes the setup service, which violates the point of unit testing: you're testing two units of code at once. |

-----

## II. The Solution: Factory Bot for Complex State

The core principle of testing setup is to define the minimal **state** required for the test, not to execute the full **logic** that creates that state. Factory Bot is designed to be a lightweight, fast model builder.

### Step 1: Define Minimal, Reusable Factories

Start with simple, minimal factories for your core models.

**`spec/factories/users.rb`**

```ruby
FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    password { "password123" }
  end
end
```

### Step 2: Handle Associations for Related Data

Handle relationships by using Factory Bot's `association` helper. This cleanly handles the complexity of creating dependent records without invoking the higher-level services.

**`spec/factories/posts.rb`**

```ruby
FactoryBot.define do
  factory :post do
    title { "My Great Post" }
    status { :published }

    # Associates the post with a created user.
    # Factory Bot handles the creation of the user factory.
    author { association :user } 
  end
end
```

### Step 3: Use Traits to Define Complex States

**Traits** are the most direct replacement for complex service logic. They let you define specific, necessary states that combine cleanly, so test setup stays fast and reads clearly.

**Goal:** Create a user who is `premium` and has an active `subscription`.

**`spec/factories/users.rb` (with Traits)**

```ruby
FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    password { "password123" }

    # Trait 1: Handles the 'premium' state
    trait :premium do
      role { :premium }
    end

    # Trait 2: Handles the 'subscribed' state, which requires an associated record.
    trait :subscribed do
      after(:create) do |user, evaluator|
        # Minimal database creation to set up the necessary state
        create(:subscription, user: user, status: :active) 
      end
    end
  end
end
```

### The Fast, Improved Test

The previous slow test now becomes fast, isolated, and clear:

```ruby
# ✅ THE IMPROVEMENT (Fast and Isolated Setup)
RSpec.describe PostPolicy do
  it "allows a premium user to view a draft post" do
    # 1. Use traits to quickly create the exact STATE needed.
    #    (This skips RegistrationService logic and emails.)
    user = create(:user, :premium, :subscribed) 
    
    # 2. Use simple creation for the post object.
    post = create(:post, author: user, status: :draft)

    # 3. The test starts immediately.
    expect(described_class).to permit(user, post)
  end
end
```

-----

## III. Skipping the Database Entirely with `build`

Not every test requires database persistence. Factory Bot offers methods to create objects in memory, skipping database interaction entirely.

| Method | Description | Persistence? | Speed | Use When... |
| :--- | :--- | :--- | :--- | :--- |
| **`create`** | Creates and **saves** the object to the database (runs validations). | Yes | Medium | You need to query the database or test persistence. |
| **`build`** | Creates an object instance **in memory** (does not save). | No | Fast | You are testing controller logic *before* the save, or methods that don't rely on `id` or persistence. |
| **`build_stubbed`** | Creates an object instance **in memory** and mocks persistence methods (`id`, `persisted?`). | No | Fastest | You are testing views, presenters, or simple reader methods. |

**Example using `build_stubbed`:**

```ruby
# Testing a presenter that only reads attributes
RSpec.describe PostPresenter do
  it "displays 'DRAFT' for an unpublished post" do
    # No need for the DB; build_stubbed is fastest
    post = build_stubbed(:post, status: :draft)
    
    expect(PostPresenter.new(post).status_label).to eq("DRAFT")
  end
end
```

-----

## The principle

Whether a test setup runs your business logic or just builds the minimal state that logic would have produced is one of the biggest levers on Rails test suite speed. Factory Bot's traits and associations let you decouple the two: the test gets the state it needs, the service that would normally create that state stays untested until something actually calls it directly.
