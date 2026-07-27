---
layout: post
title: "Fixing Deterministic Rails CI Failures Without Teaching the Tests to Lie"
date: 2026-07-23 08:57:34 +0100
author: "Joey Wang"
description: "A Rails debugging story about following CI evidence, fixing shared test state, and resisting the urge to weaken assertions."
tags: [rails, rspec, capybara, ci, testing]
categories: [Ruby on Rails]
---

# Fixing deterministic Rails CI failures without teaching the tests to lie

<audio controls preload="metadata" src="/assets/audio/2026-07-23-fixing-deterministic-rails-ci-spec-failures-summary.ogg">
  Your browser does not support the audio element.
</audio>

The tempting thing, when a CI suite is red for the tenth time, is to make the test less demanding.

Increase the Capybara wait time. Add a retry. Loosen the assertion. Skip the example in CI. Tell yourself browser specs are flaky anyway.

Sometimes that is the right move. Usually it is not the first move.

Recently I spent a long debugging session on a Rails test suite where the failures looked like ordinary feature-spec noise at first glance. Admin pages could not find buttons that should have been there. Registration specs could not find cards that were part of the happy path. A request spec expected a rate limit and got a normal response. A few examples failed only after other files had already run.

The important detail was that the failures were not random. They were deterministic once the CI order and environment were reproduced. The suite was telling a story. We just had to stop reading each assertion in isolation.

This is the public version of the story. I removed project names, private URLs, branch names, run IDs, internal hostnames, credentials, and business-specific identifiers. The useful part is the debugging shape: Rails test state, browser sessions, authentication helpers, factory semantics, and order-dependent configuration.

## The first clue: the page was wrong, not the selector

One of the early failures looked like this:

```text
expected to find css ".admin-card" but there were no matches
```

That sounds like a front-end timing problem. Maybe the card is loaded by JavaScript. Maybe the selector changed. Maybe the page needs another wait.

But the screenshot and saved HTML showed something more useful: the browser was not on the admin page at all. It was on the sign-in page.

That changes the diagnosis completely.

If a feature spec expects an admin page and the artifact shows a login page, the failing selector is only the smoke. The fire is authentication or session state:

- the factory user may not be active for authentication;
- the helper may be signing in through a path the browser cannot see;
- the session may be reset between the helper and the request;
- the user record may have been deleted or made stale by another example;
- the test may be running under a driver with different session behaviour in CI.

This is why I like to read the page content before touching the assertion. Capybara failures often report the symptom at the DOM boundary. The saved HTML tells you what the app actually did.

## CI artifacts are not optional evidence

Local browser specs were unreliable in this case because the local Chrome/driver setup was not the same as CI. That meant the CI artifacts became the source of truth: failed logs, screenshots, and generated HTML.

The loop became simple:

```bash
# Representative shape only; avoid embedding private run or repo identifiers in notes.
gh run view <run-id> --log-failed > /tmp/failed.log
gh run download <run-id> --name artifact --dir /tmp/artifacts
```

Then inspect the artifacts, not just the failure summary. I do not want to guess from the matcher text when CI already wrote the page HTML to disk.

The difference matters. A failure summary might say:

```text
Unable to find link or button "Save"
```

The HTML might say:

```text
You need to sign in before continuing
```

Those are not the same problem.

A good debugging rule for feature specs is:

> Never fix the selector until you have confirmed the browser is on the page the test thinks it is on.

## Factory defaults are domain state, not convenience

The first real bug was factory state.

The application uses Devise-style account confirmation. A user can exist in the database and still be inactive for authentication. That is easy to forget in tests because factories tend to become a convenience layer: `create(:admin)` feels like it should mean “a user who can log in.”

For admin feature specs, that is usually true. For registration specs, it may be exactly false.

We had both kinds of tests:

- admin specs that need a confirmed, active user;
- registration specs that intentionally start with an unconfirmed user and then verify activation, registration, and email behaviour.

A broad factory change fixed one class of failures and broke another. Making every factory user confirmed stopped admin specs from redirecting to login, but it damaged registration flows that depended on the unconfirmed state.

The better rule was narrower:

```ruby
# Pseudocode, not copied from the private codebase.
factory :user do
  # Keep the base user neutral.
end

factory :admin, parent: :user do
  confirmed_at { Time.current }
end

trait :unconfirmed do
  confirmed_at { nil }
end
```

The lesson is not “always confirm users” or “never confirm users.” The lesson is that factory defaults encode domain state. If the domain has meaningful lifecycle states, the base factory should not silently choose the most convenient one for every test.

Make the state explicit at the boundary that needs it:

- authentication helpers can ensure the user they sign in is active;
- registration specs can create unconfirmed users deliberately;
- role-specific factories can represent roles that are normally active in admin flows.

## Memoized test helpers can outlive the database row

Another class of failure came from a helper that cached a user across examples.

That is a tiny optimization with a nasty failure mode. Test databases are usually cleaned between examples. If a helper memoizes an ActiveRecord object and the underlying row disappears, later examples can hold a Ruby object that looks valid but no longer represents a usable record.

The fix was simple: do not memoize a database record across examples unless the lifecycle is extremely clear. Build or find the record inside the example boundary.

```ruby
# Risky shape
# @admin ||= create(:admin)

# Safer shape
def admin_user
  create(:admin)
end
```

There are exceptions. Sometimes a suite-level fixture is worth it. But when debugging authentication failures, stale users belong on the suspect list.

## Warden helpers and Selenium do not always share a world

Devise and Warden give us fast test helpers like `login_as(user)`. They are excellent for request specs and many integration specs. The trap is assuming that a Warden-level login is identical to a browser-level login in every Capybara driver.

With a Rack test driver, the test and the app live close together. A helper can manipulate the rack session and the next request sees it.

With Selenium, a real browser talks to a server. The helper may run in the test process while the browser session lives somewhere else. Depending on the app, driver, host, session store, and middleware, direct Warden injection may not establish the state the browser needs.

In our case, artifacts showed that some feature specs were still landing on the login page after helper-based sign-in. The fix was to make feature-spec login go through the same path a user takes: visit the login page, fill in the form, submit it, and let the browser receive the real session cookie.

The important part was applying that rule centrally. Some specs used a project helper like `login_as_admin`. Others called `login_as(user)` directly. Fixing only the project helper improved the failure signature, but did not remove the class of failure.

A more robust shape is:

```ruby
# Pseudocode.
module FeatureLogin
  def login_as(user, options = {})
    return super unless current_example_is_feature_spec?

    ensure_user_can_authenticate(user)
    sign_out_if_browser_is_already_authenticated

    visit "/login"
    fill_in "email", with: user.email
    fill_in "password", with: test_password
    click_on "Sign in"

    user
  end
end
```

Two details made this less surprising later:

1. The override only applies to feature specs. Request and controller specs can keep using the faster Warden path.
2. The helper signs out first if the browser is already authenticated. Nested `before` blocks sometimes call login helpers more than once. Without a sign-out guard, the second login attempt can try to fill a login form while already on an authenticated page.

That second detail is easy to miss because it only appears after you fix the first login problem.

## Reset Warden between examples

Warden also has suite-level state. If you enable Warden test mode, reset it after each example.

```ruby
RSpec.configure do |config|
  config.before(:suite) do
    Warden.test_mode!
  end

  config.after(:each) do
    Warden.test_reset!
  end
end
```

This is not a magic fix for every auth problem. It just removes one source of cross-example leakage. When the suite is already order-sensitive, removing hidden state is almost always worth doing.

## Do not debug browser state and driver changes at the same time

At one point the failure signature was broad enough that the Selenium configuration itself became suspect. Browser feature specs are sensitive to small differences:

- headless mode flags;
- host and port configuration;
- session cookie domain;
- remote browser options;
- driver version;
- JavaScript execution timing.

The safest move was not to invent a new driver configuration while also changing auth helpers. The safer move was to return the CI driver setup to a known-good baseline, then continue debugging app/test state from there.

This is a general rule I keep relearning:

> When authentication, sessions, and Selenium are all in the failure area, reduce driver novelty before changing application assumptions.

## Watch the failure signature change

The most useful signal was not a single green run. It was the way failures moved.

The sequence looked like this:

1. Many admin feature specs showed login pages.
2. Confirming the right users and avoiding stale cached users reduced one cause but did not eliminate browser-session problems.
3. Switching feature login to the real UI removed the login-page signature.
4. The remaining failures moved into registration flows, date-sensitive availability windows, email expectations, and a request throttling spec.

That movement is progress. It means you are peeling off failure classes rather than randomly poking the suite.

I like to keep a small table while doing this:

| Run | Dominant failure signature | Interpretation |
|---|---|---|
| A | Admin specs render login page | Auth/session setup suspect |
| B | Some admin specs still unauthenticated | Not all specs use the same login helper |
| C | No login redirects; registration expectations fail | Factory lifecycle or registration state suspect |
| D | Request throttling fails only in full order | Shared Rack/config/env state suspect |

The exact run identifiers do not matter. The pattern does.

## Request specs can leak configuration too

One non-browser failure expected a rate limit response and got a normal response.

Run alone, the spec passed. Run after other specs, it failed. That is almost always a shared-state smell.

Rack middleware and security libraries often keep configuration in global process state. Environment variables can also be read at initializer load time. If a spec depends on a particular throttle being enabled, it should pin that condition inside the spec and restore it afterward.

A useful pattern is:

```ruby
# Pseudocode.
before do
  @old_env = ENV.to_hash.slice("FEATURE_FLAG", "THRESHOLD")

  ENV["FEATURE_FLAG"] = "true"
  ENV["THRESHOLD"] = "20"

  Rack::Attack.clear_configuration
  load Rails.root.join("config/initializers/rack_attack.rb")
  Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new
  Rack::Attack.reset!
end

after do
  Rack::Attack.clear_configuration
  restore_env(@old_env)
  load Rails.root.join("config/initializers/rack_attack.rb")
end
```

The goal is not to make the spec know every production setting. The goal is to make the spec own the state it is asserting.

## Time travel is another hidden global

Date-sensitive registration specs are another place where deterministic CI failures hide.

Libraries like Timecop and Rails time helpers are useful, but time is process-global enough that I treat it like database state: every travel needs a return, and helper methods that freeze time should use block forms where possible.

```ruby
Timecop.freeze(record.start_at) do
  visit dashboard_path
  expect(page).to have_text("Start")
end
```

Avoid open-ended time travel in feature specs unless there is a very good reason. Browser specs already have enough moving parts: server process, browser process, async JavaScript, database state, and session cookies. A leaked clock makes every one of those harder to reason about.

## The checklist I wish I had started with

If I see deterministic CI spec failures in a Rails app now, especially around Capybara and Devise, I use this checklist before changing assertions:

1. **Read the artifact HTML.** Is the browser on the expected page?
2. **Classify the failure signature.** Login page, wrong role, blank state, validation page, missing JavaScript widget, or real assertion mismatch?
3. **Check factory lifecycle state.** Is the user confirmed, activated, enrolled, registered, expired, or intentionally not one of those?
4. **Check helper boundaries.** Does the spec use the same helper path as the browser driver can observe?
5. **Reset auth state.** Warden, sessions, cookies, and repeated login helpers need clear boundaries.
6. **Avoid stale memoized records.** Do not keep ActiveRecord objects across examples unless the database lifecycle matches.
7. **Pin order-sensitive config.** Middleware, feature flags, cache stores, and environment-derived settings should be owned by the spec.
8. **Use CI as evidence when local browser setup differs.** Local failure is useful, but not authoritative if the driver stack is different.
9. **Make one class of change at a time.** A moving failure signature is a debugging signal. Preserve it.
10. **Do not weaken the test until you know what it was really testing.**

## What not to do

The worst fix would have been to add waits everywhere.

```ruby
sleep 2
expect(page).to have_css(".thing")
```

That might hide a timing bug. It will not fix an inactive user, a browser that never received a session cookie, a globally disabled throttle, or a factory that skipped the lifecycle the test is trying to exercise.

The second worst fix would have been to make every user factory fully active by default. That made admin specs happier for a moment, but registration specs exist precisely to prove that activation and confirmation happen at the right time. A test helper should not erase the state transition the feature is meant to test.

## The part worth keeping

A red CI run is not just a list of broken examples. It is a dataset.

The failed assertion tells you where the test noticed the problem. The screenshot tells you where the browser actually was. The HTML tells you what the app rendered. The order tells you which hidden state may have leaked. The way the failures change after each patch tells you whether you are removing causes or just moving noise around.

The useful move is not clever. It is boring and specific:

- inspect the evidence;
- classify the failure;
- change the smallest shared boundary that explains it;
- verify locally where the local environment is trustworthy;
- let CI prove the browser path;
- repeat until the failure signature changes for a reason you can explain.

That is slower than adding a retry. It also keeps the test suite useful. The suite should tell you when the app is wrong, not repeat whatever lie made the last CI run green.
