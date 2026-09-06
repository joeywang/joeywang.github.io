---
layout: post
title:  "Rails UJS to Turbo: the event timing bug CI didn't catch"
description: "Migrating Rails UJS to Turbo can silently break submit buttons and resets in production, because Turbo's event timing and Promise handling differ from UJS."
date:  2026-06-01
categories: [Rails]
tags: [rails, javascript, testing, debugging]
---

<audio controls preload="metadata" src="/assets/audio/turbo-upgrade-article-summary.ogg">
  Your browser does not support the audio element.
</audio>

## The silent failure

Our Rails application had been running smoothly for years on Turbolinks and Rails UJS for AJAX form submissions. When we upgraded to Rails 7 and Turbo (Hotwired), the deployment went without a hitch and the test suite was green. Everything appeared to work.

Production users hit a wall immediately: submit buttons stayed disabled, results didn't display, and interactive exercises couldn't be reset. The tests passed. The app was broken.

This is what we found when we dug into Turbo's event lifecycle, and how to migrate from Rails UJS to Turbo without falling into the same traps.

## The application

Ours is an English learning platform where students answer introduction questions, complete article comprehension quizzes, submit opinions and see poll results, and practice interactive exercises (Highlighter, Word Match, Blockbuster) that they can reset and retry.

The core UX pattern: submit buttons start disabled and enable once all questions are answered, so partial submissions can't happen. The implementation relied on AJAX form submissions with Stimulus controllers listening for success events to enable submit buttons, display results, and reset activities.

## What broke, silently

After the upgrade to Turbo:

- Users answered all five questions, but the submit button never enabled.
- Clicking Submit produced no feedback. The page looked frozen.
- Clicking Reset after completing an exercise did nothing.

Our integration tests passed the whole time; they completed full lesson flows successfully. We only found the bugs when QA manually tested the reset functionality, something the automated tests never exercised.

## Root cause: the event format changed

Our JavaScript controllers were written for Rails UJS, which emits a custom `ajax:success` event with its own data shape:

```javascript
// Rails UJS event format
document.addEventListener('ajax:success', (event) => {
  const [data, status, xhr] = event.detail
  const responseText = data           // HTML string
  const statusCode = xhr.status       // 200, 201, 202, etc.
})
```

Turbo intercepts form submissions and never fires that event. It emits its own events with a different shape entirely:

```javascript
// Turbo event format
document.addEventListener('turbo:submit-end', (event) => {
  const response = event.detail.fetchResponse.response
  const responseText = event.detail.fetchResponse.responseText  // Promise!
  const statusCode = response.status
})
```

Our controllers were listening for events that never fired, so the UI never updated.

## The false fix: supporting both formats

Our first attempt tried to handle both event shapes in one method:

```javascript
// This looks reasonable but has three separate bugs
update(event) {
  let html, code

  if (event.detail && event.detail.length > 1) {
    // Rails UJS format
    html = event.detail[0]
    code = event.detail[2]?.status
  } else if (event.detail?.fetchResponse) {
    // Turbo format
    html = event.detail.fetchResponse.responseText
    code = event.detail.fetchResponse.response.status
  }

  this.element.innerHTML = html

  if (code === 202) {
    this.enableSubmitButton()
  }
}
```

**`responseText` is a Promise, not a string.** Using it directly sets `innerHTML` to the literal text `[object Promise]` instead of the HTML we wanted.

**Event timing was wrong.** We were listening on `turbo:submit-end`, which fires after Turbo has already tried to process the response, navigate, or update the page. By that point `event.preventDefault()` does nothing, and you get a console error: "Form responses must redirect to another location."

**The migration was incomplete.** With dual-format code covering both event shapes, it's easy to miss updating a form in a view. That form's listener never fires, and it fails silently with no error to point at it.

## The fix: migrate to Turbo completely

**Use `turbo:before-fetch-response`, not `turbo:submit-end`.** The event lifecycle for a Turbo form submission is:

```
turbo:submit-start           -> form about to submit (can cancel)
turbo:before-fetch-request   -> HTTP request about to send (can modify)
turbo:before-fetch-response  -> response received, not yet processed  <- use this
turbo:submit-end             -> response processed (too late for preventDefault)
```

`turbo:before-fetch-response` fires before Turbo processes the response, so `event.preventDefault()` actually stops Turbo's own navigation and hands you the response to handle manually:

```javascript
async replace(event) {
  event.preventDefault()  // stops Turbo navigation

  const html = await event.detail.fetchResponse.responseText
  this.element.outerHTML = html
}
```

**Await every Promise.** `FetchResponse.response.status` and `.response.ok` are plain values you can read directly. `responseText` and `responseHTML` are Promises and must be awaited.

**Update every view.** Every form using `data: { action: 'ajax:success->...' }` needs to change to the Turbo event name:

```diff
  <%= form_with url: answer_path,
-               data: { action: 'ajax:success->result#update' } %>
+               data: { action: 'turbo:before-fetch-response->result#update' } %>
```

This has to be complete. A mix of Rails UJS and Turbo event handlers across different forms produces silent, per-form failures that are hard to trace back to the migration.

## Before and after: the submit button controller

Before, on Rails UJS:

```javascript
// app/frontend/controllers/result_controller.js
import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = ['form']

  update(event) {
    const [data, status, xhr] = event.detail

    if (status === 'Accepted' || xhr.status === 202) {
      this.formTarget.disabled = false
      this.formTarget.querySelectorAll('[type="submit"]').forEach(submit => {
        submit.disabled = false
      })
    }
  }
}
```

```slim
/ app/views/user_lessons/_1_introduction.html.slim
= form_with url: answer_user_lesson_path(@user_lesson),
            data: { action: 'ajax:success->result#update' }
```

After, on Turbo:

```javascript
// app/frontend/controllers/result_controller.js
import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = ['form']

  update(event) {
    event.preventDefault()  // stop Turbo from processing the response itself

    const code = event.detail.fetchResponse.response.status

    if (code === 202) {  // all questions answered
      this.formTarget.disabled = false
      this.formTarget.querySelectorAll('[type="submit"]').forEach(submit => {
        submit.disabled = false
      })
    }
  }
}
```

```slim
/ app/views/user_lessons/_1_introduction.html.slim
= form_with url: answer_user_lesson_path(@user_lesson),
            data: { action: 'turbo:before-fetch-response->result#update' }
```

The event name changed, `preventDefault()` was added, and `event.detail[2].status` became `event.detail.fetchResponse.response.status`. The dual-format branching is gone.

## Before and after: the content replacement controller

Before:

```javascript
// app/frontend/controllers/section_controller.js
replace(event) {
  const html = event.detail[0]  // responseText string
  this.element.outerHTML = html
}
```

After:

```javascript
// app/frontend/controllers/section_controller.js
async replace(event) {
  event.preventDefault()

  const html = await event.detail.fetchResponse.responseText
  this.element.outerHTML = html
}
```

The method became `async` so it could `await` the `responseText` Promise, and the dual-format handling disappeared entirely.

## The testing trap

Our integration tests passed because they only exercised the happy path:

```ruby
# test/system/take_lesson_test.rb (insufficient)
test 'complete lesson' do
  visit lesson_path(@lesson)

  choose 'True'
  click_on 'Submit'

  5.times { |i| choose "Answer #{i}" }
  click_on 'Submit'

  assert_text 'Congratulations!'
end
```

It confirmed forms submit and content updates after submission, but it never checked submit button state transitions, never clicked a Reset button, and never verified the correct/wrong feedback indicators. The test verified lesson completion, not the interaction the user actually has with the page.

We rewrote it to check the states that had broken:

```ruby
# test/system/take_lesson_test.rb (comprehensive)
test 'take lesson with full UX verification' do
  visit lesson_path(@lesson)

  within('div[data-target="lesson.introPart"]') do
    submit_button = find('button[type="submit"]')
    assert submit_button.disabled?, 'Submit button should start disabled'

    choose 'False'

    sleep 1
    assert !submit_button.disabled?, 'Submit button should enable after answering'

    click_on 'Submit'
  end

  within('div[data-target="lesson.introPart"]') do
    assert_text 'Well done!'
  end

  within('div[data-controller="highlighter"]') do
    within('#hq-1') do
      find('span[data-flag="c"]', text: 'even as').click
      click_on 'Check Answer'
      assert_text 'Well done!'
    end

    assert_text 'Click Reset to take the activity again'
    click_on 'Reset'

    within('#hq-1') do
      assert_text 'Which linking phrase in paragraph one shows contrast?'
      assert_no_text 'Well done!'
    end

    within('#hq-1') do
      find('span[data-flag="c"]', text: 'even as').click
      click_on 'Check Answer'
      assert_text 'Well done!'
    end
  end
end
```

That version checks the disabled state, the enable transition, the results display, the reset behaviour, and that the exercise still works after a reset. It's the version that would have caught the bugs before production did.

## Migration checklist

The mechanics that mattered in practice: grep the codebase for every `ajax:success`, `ajax:error`, and `ajax:complete` listener and every form using `data: { action: 'ajax:*' }`, then update each controller's event name, add `preventDefault()`, replace `event.detail[n]` with the `fetchResponse` equivalents, await the Promise-returning properties, and make the method `async` where needed. Do the same for every view. Replace any leftover `Rails.fire()` calls with `form.requestSubmit()`, and drop `remote: true` since Turbo already intercepts the form. Once the code is updated, `grep -r "ajax:success\|ajax:error\|ajax:complete" app/views/` should return nothing. Only after that should tests be rewritten to check button state, reset behaviour, and error paths, followed by manual QA of every interactive form.

## Alternative: Turbo Streams

Instead of manually intercepting the response and replacing HTML, Turbo Streams push the update from the server:

```ruby
def create
  @result = process_answer(params[:answer])

  respond_to do |format|
    format.turbo_stream
  end
end
```

```erb
<%# create.turbo_stream.erb %>
<%= turbo_stream.replace "section-intro" do %>
  <%= render partial: "intro_results", locals: { result: @result } %>
<% end %>

<%= turbo_stream.update "submit-button" do %>
  <button type="submit" <%= "disabled" unless @all_answered %>>Submit</button>
<% end %>
```

No `preventDefault()`, no manual HTML replacement, no Promise handling: the server drives the UI. The tradeoff is a larger refactor and dedicated `turbo_stream` views for every response. We kept manual handling because the migration surface was smaller and our existing server responses worked as-is; Turbo Streams make more sense for a new project or one that already needs real-time updates.

## Performance

The request count doesn't change: one fetch per form submission either way. Turbo fires more JavaScript events around that fetch (`turbo:submit-start`, `turbo:before-fetch-request`, `turbo:before-fetch-response`, `turbo:submit-end` versus a single `ajax:success`), but the extra events cost microseconds. Turbo's caching and prefetching more than make up for it in practice.

## The principle

Rails UJS to Turbo is not a drop-in replacement: the event formats, the timing, and the semantics are all different, and the migration has to be complete or it fails silently, form by form. The more useful lesson is about the tests: a green suite told us nothing about whether users could actually use the page. Test the interaction, not just the outcome. If a test can pass while a real user is stuck looking at a disabled button, the test is checking the wrong thing.

Our migration touched 18 controller files and 8 view files.

## Resources

- [Turbo Handbook](https://turbo.hotwired.dev/handbook/introduction)
- [Turbo Events Reference](https://turbo.hotwired.dev/reference/events)
- [FetchResponse API](https://github.com/hotwired/turbo/blob/main/src/http/fetch_response.ts)
- [Stimulus Handbook](https://stimulus.hotwired.dev/handbook/introduction)
