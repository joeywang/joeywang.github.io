---
layout: post
title: "The CI failures that moved every time you reran them"
date: 2026-08-07 09:45:00 +0100
author: "Joey Wang"
description: "How a moving set of Rails CI flakes exposed shared download state, Chrome/Selenium stale-node retries, and feature specs that asserted before the browser had settled."
tags: [engineering, testing, ci, ruby, rails, debugging]
categories: [Engineering]
---

Every time we reran the failing CI job, a different spec failed. Same error message, different victim. That alone should have told us what was happening, but it took a few reruns and a merged pull request to see the first bug.

Then CI moved again.

This is the story of a flaky test suite that wasn't one problem. It was a small cluster of assumptions that only became visible under parallel CI and a newer browser.

## The symptom

Our Rails app runs its feature specs in CI with `parallel_tests` — seven RSpec processes sharing one database setup. A normal merge to `main` triggers the full suite.

After merging a small mailer change, the CI run came back red:

```text
X execution expired
JUnit Test Report: ./spec/features/admin/registrations_spec.rb#32
```

`execution expired` is Ruby's `Timeout::Error`. The spec that failed was downloading a CSV and waiting for the file to appear. I looked at the spec locally, ran it, and it passed in five seconds.

Fine. Flaky spec. Rerun the failed job and move on.

The rerun failed again. This time on two *different* specs:

```text
X execution expired
JUnit Test Report: ./spec/features/admin/registrations_spec.rb#109
X execution expired
JUnit Test Report: ./spec/features/admin/programs_spec.rb#167
```

Same error. Different lines. None of the three specs had anything to do with the mailer change I had just merged. (I'm deliberately using placeholder spec names and leaving out run IDs here — the numbers and names don't matter, the shape does.)

## The pattern hiding in the failures

By now the shape of the problem was hard to miss. Every failure was:

- a feature spec that downloads a file (CSV export, file attachment, PDF)
- timing out at exactly the same 60-second threshold
- a *different* spec each run

All three specs used the same test helper:

```ruby
module DownloadHelpers
  TIMEOUT = ENV.fetch('DOWNLOAD_TIMEOUT', 60).to_i
  PATH = Rails.root.join('tmp', 'downloads').freeze

  def wait_for_download
    Timeout.timeout(TIMEOUT) do
      sleep 0.5 until downloaded?
    end
  end
end
```

And here is the part that made it intermittent: in `rails_helper.rb`, every single feature spec clears the download folder before it runs:

```ruby
config.before(:each, type: :feature) do
  DownloadHelpers.clear_downloads
end
```

`clear_downloads` does `FileUtils.rm_r` on everything in `tmp/downloads`.

Now think about what happens with seven parallel processes. Process 3 clicks "Download" and starts polling for the file. Process 5 starts a feature spec, runs `before(:each)`, and deletes every file in the shared `tmp/downloads` folder. Process 3's file vanishes before the poll sees it. It waits, polls, waits, and dies 60 seconds later with `execution expired`.

It was a race. A shared mutable directory, seven processes, and a cleanup step that assumes it owns the folder. No wonder the failure moved around — it depended entirely on which processes happened to overlap in that window.

## Why local runs were always green

This is the part that made the whole thing confusing at first. Every spec passed on my machine, every time.

Because on my machine there is exactly one RSpec process. It clears the download folder, downloads the file, reads it, and clears again. There is nobody else deleting files out from under it. The race needs two processes, and locally there is only one.

The same commit that was green in one CI run was red in another. That should have been the tell. A genuinely broken spec fails the same way every time. A spec that fails differently each run is usually a victim of something else.

## The fix: give every process its own folder

The app already had the answer waiting in `config/application.rb`. Under `parallel_tests`, each process gets a `TEST_ENV_NUMBER`, and the app already uses it to give each process its own Redis database:

```ruby
if ENV['RAILS_ENV'] == 'test' && ENV['TEST_ENV_NUMBER'].to_s != ''
  # shift each process onto its own redis db
end
```

The download helper just needed the same treatment:

```ruby
module DownloadHelpers
  test_env_number = ENV.fetch('TEST_ENV_NUMBER', nil).to_s
  PATH = Rails.root.join(
    'tmp',
    'downloads',
    test_env_number.empty? ? '' : "process_#{test_env_number}"
  ).freeze
end
```

Process 3 downloads into `tmp/downloads/process_3`, process 5 clears `tmp/downloads/process_5`. They never touch each other's files. I also made `clear_downloads` create the directory first, because Chrome will not reliably create a missing nested download folder on its own.

One commit, one file changed:

```text
test: isolate download dir per parallel test process
```

CI came back green. The flaky suite stopped failing in that particular way, because it had never really been flaky — it had been a shared-state bug that only existed when the suite ran in parallel.

But that was not the end of the story.

## The second pattern: stale browser nodes

After the download-folder fix, the failures changed shape. They were no longer clean 60-second timeouts. Instead, feature specs sometimes died while Capybara was interacting with dynamic widgets:

```text
unknown error: unhandled inspector error:
{"code":-32000,"message":"Node with given id does not belong to the document"}
```

That is Chrome telling Selenium that a DOM node disappeared between lookup and action. In older or simpler cases, Selenium reports this as a normal stale-element error, and Capybara knows how to retry it inside its synchronization loop. This one came through as a generic Selenium unknown error, so Capybara treated it as fatal.

The tempting fix is dangerous: catch the message and let Capybara retry forever until the global wait expires.

That makes the suite quieter, but it also makes CI slower. A real failure now burns the whole wait window before it tells you anything useful.

The fix I wanted was narrower:

```ruby
module CapybaraChromeStaleNodeFix
  CDP_STALE_NODE_MESSAGE = 'does not belong to the document'
  MAX_CDP_STALE_NODE_RETRIES = 2
  CDP_STALE_NODE_RETRY_WINDOW_SECONDS = 0.5

  def catch_error?(error, errors = nil)
    if chrome_stale_node_error?(error) && retry_chrome_stale_node_error?
      true
    else
      super
    end
  end
end
```

The important part is not the exact constants. It is the shape of the guard:

- only this Chrome CDP stale-node message is treated as retryable
- only a short burst is retried
- repeated failures fail fast instead of consuming the full Capybara wait

That is the difference between stabilizing a transient browser race and hiding a broken spec behind a slower timeout.

## The third pattern: waits that were too broad

We also had explicit helpers like `wait_for_ajax` and `wait_for_page_to_settle`. They used `Capybara.default_max_wait_time`, which is reasonable for user-facing assertions but too generous for a tiny internal settle check.

If the page is basically ready and we are only waiting for current AJAX requests or a progress bar to disappear, we should not spend the same budget as a real browser assertion.

So those helpers moved to a small explicit wait:

```ruby
CAPYBARA_FAST_WAIT_SECONDS = 1.0
CAPYBARA_POLL_INTERVAL_SECONDS = 0.05

def wait_for_ajax(timeout_seconds = CAPYBARA_FAST_WAIT_SECONDS)
  wait_until_with_timeout(timeout_seconds, 'Timed out waiting for ajax requests to finish') do
    finished_all_ajax_requests?
  end
end
```

I also avoided wrapping browser calls with Ruby's `Timeout.timeout`. Interrupting Selenium in the middle of a WebDriver call is not a great failure mode. A monotonic deadline loop is boring, but boring is good here.

## The last two flakes were test assumptions

One CI run after the retry change still failed, this time with two ordinary-looking assertion failures.

The first was an announcement-editing spec. The spec tried to remove all selected program filters by mutating Selectize's hidden input directly with JavaScript, then submitting the form. The visual labels disappeared, but the submitted form value could still contain the old selected IDs under CI timing.

That is not a product bug. It is a test that bypassed the UI and then expected UI state, Selectize state, and form state to agree.

The fix was to exercise the path a user actually takes: remove the visible labels, wait for the selected options to disappear, and submit the specific admin form.

The second was a registration spec. After submitting a sign-in form, it immediately asserted that the database association existed. Locally it usually did. In CI, the browser had not always completed the redirect/session flow before the assertion ran.

The fix was not another sleep. It was to wait for the visible post-login page state first:

```ruby
fill_in_sign_in_form(user.email)
expect(page).to have_text('Programs')
expect(user.reload.registration_items.count).to eq 1
```

Feature specs should synchronize on what the user can see. If the user-visible page is not there yet, the test has no business asserting the side effect as if the flow had finished.

## The lessons

1. **A different spec failing every rerun is itself a clue.** A broken test fails the same way every time. A moving failure points at shared state, browser timing, or a helper assumption that many tests share.

2. **Check what the tests share before blaming the tests.** Parallel test suites run the same code in the same working directory. Files, folders, ports, Redis keys, environment variables, browser helpers — anything shared is a candidate. In our case the app had already solved this for databases and Redis; the downloads folder was simply the one thing nobody had partitioned yet.

3. **Timeouts that always hit the same limit are a smell.** A 60-second timeout that always burns the full 60 seconds is not a slow test. It is a test waiting for something that will never arrive. Retrying a browser error through the full Capybara wait can create the same problem in a different form.

4. **Local green runs do not clear CI.** Single-process local runs cannot reproduce races that need concurrency. If a spec only fails under parallel CI, try reproducing it with two processes and a shared resource, or just look for the shared resource directly.

5. **Make retries bounded and specific.** A retry should describe the transient failure it is meant to absorb. If it catches too much, or waits too long, it becomes a performance bug and hides useful failures.

6. **Synchronize feature specs on user-visible state.** Waiting for a page heading, menu, or result is better than asserting the database immediately after a click. Capybara is good at waiting for the browser; use that instead of racing the browser from Ruby.

The first fix was ten lines in a test helper. The later fixes were smaller but more subtle: a bounded browser retry, shorter explicit waits, and two feature specs changed to synchronize on the UI instead of internal state.

The expensive part was not the code. It was accepting that "flaky CI" was not a single diagnosis. It was a queue of small incorrect assumptions, and each green run only proved that we had removed the current one.
