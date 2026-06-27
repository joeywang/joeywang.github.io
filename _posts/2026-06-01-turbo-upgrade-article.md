---
layout: post
title:  "Migrating from Rails UJS to Turbo: The Hidden Pitfalls That Broke Our Production App"
date:  2026-06-01
categories: Rails
---

# Migrating from Rails UJS to Turbo: The Hidden Pitfalls That Broke Our Production App

**A cautionary tale about event timing, async promises, and why your tests might be lying to you**

---

## The Silent Failure

Our Rails application had been running smoothly for years with Turbolinks and Rails UJS handling AJAX form submissions. When we upgraded to Rails 7 and Turbo (Hotwired), the deployment went without a hitch. Our test suite was green. Everything *appeared* to work.

But production users immediately hit a wall: submit buttons stayed disabled, results didn't display, and interactive exercises couldn't be reset. **The tests passed, but the app was broken.**

This is the story of how we debugged the issue, what we learned about Turbo's event lifecycle, and how to properly migrate from Rails UJS to Turbo without falling into the same traps.

---

## The Architecture: A Learning Platform

Our application is an English learning platform where students:
1. Answer introduction questions (yes/no)
2. Complete article comprehension (5 multiple choice)
3. Submit opinions and see poll results
4. Practice with interactive exercises (Highlighter, Word Match, Blockbuster)
5. Reset and retry exercises for mastery

The key UX pattern: **submit buttons start disabled and enable when all questions are answered**. This prevents partial submissions and guides the user through the workflow.

The implementation relied heavily on AJAX form submissions with JavaScript controllers listening to success events to:
- Enable submit buttons (when all answers collected)
- Display results (correct/wrong feedback)
- Reset activities (replace content with fresh state)

---

## The Symptom: Everything Breaks Silently

After upgrading to Turbo, users encountered:

### Problem 1: Submit Buttons Never Enable
```
User answers all 5 questions → Submit button stays disabled → Cannot proceed
```

### Problem 2: No Results Display
```
User clicks Submit → No feedback appears → Page looks frozen
```

### Problem 3: Reset Buttons Don't Work
```
User completes exercise → Clicks Reset → Nothing happens
```

The confusing part? **Our integration tests passed.** The test suite completed full lesson flows successfully. We only discovered the bugs when QA manually tested the reset functionality—something our automated tests never exercised.

---

## The Root Cause: Event Format Changes

Our JavaScript controllers were written for Rails UJS, which emits custom events like `ajax:success` with a specific data format:

```javascript
// Rails UJS event format
document.addEventListener('ajax:success', (event) => {
  const [data, status, xhr] = event.detail
  const responseText = data           // HTML string
  const statusCode = xhr.status       // 200, 201, 202, etc.
})
```

When we upgraded to Turbo, **these events stopped firing**. Turbo intercepts form submissions and emits its own events with a completely different format:

```javascript
// Turbo event format
document.addEventListener('turbo:submit-end', (event) => {
  const response = event.detail.fetchResponse.response
  const responseText = event.detail.fetchResponse.responseText  // ⚠️ Promise!
  const statusCode = response.status
})
```

Our controllers were listening to events that never fired, so they never updated the UI.

---

## The False Fix: Dual Format Support

Our first attempt tried to support both formats:

```javascript
// ❌ This seems reasonable but has subtle bugs
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

**This code has three critical bugs:**

### Bug 1: `responseText` is a Promise

The Turbo `FetchResponse.responseText` is a **Promise**, not a string. Using it directly results in:

```javascript
this.element.innerHTML = html  // Sets innerHTML to "[object Promise]"
```

The UI updates with literal text `[object Promise]` instead of the HTML we wanted.

### Bug 2: Wrong Event Timing

We initially used `turbo:submit-end`, which fires **after** Turbo has already processed the response. At that point:
- Turbo has already tried to navigate or update the page
- Calling `event.preventDefault()` does nothing
- We get console errors: "Form responses must redirect to another location"

### Bug 3: Incomplete Migration

With dual-format code, it's easy to miss updating all the forms in your views. One form still using `ajax:success` will silently fail because the event never fires.

---

## The Correct Solution: Complete Migration to Turbo

### Step 1: Use the Right Event

**Use `turbo:before-fetch-response` instead of `turbo:submit-end`:**

```javascript
// ✅ Correct: Intercept before Turbo processes the response
async replace(event) {
  event.preventDefault()  // Stops Turbo navigation
  
  const html = await event.detail.fetchResponse.responseText
  this.element.outerHTML = html
}
```

**The Turbo event lifecycle:**

```
turbo:submit-start           → Form about to submit (can cancel)
  ↓
turbo:before-fetch-request   → HTTP request about to send (can modify)
  ↓
turbo:before-fetch-response  → Response received, NOT processed ⭐ USE THIS
  ↓
turbo:submit-end             → Response processed (too late for preventDefault)
```

**Why `turbo:before-fetch-response`?**
- Fires before Turbo processes the response
- `event.preventDefault()` successfully stops navigation
- Gives you the response to handle manually
- Prevents "Form responses must redirect" errors

### Step 2: Await All Promises

```javascript
// ✅ Correct: Await the Promise
const html = await event.detail.fetchResponse.responseText

// ❌ Wrong: Using Promise directly
const html = event.detail.fetchResponse.responseText  // [object Promise]
```

**FetchResponse properties:**

| Property | Type | Usage |
|----------|------|-------|
| `response.status` | `number` | Direct access ✅ |
| `response.ok` | `boolean` | Direct access ✅ |
| `responseText` | `Promise<string>` | Must `await` ⚠️ |
| `responseHTML` | `Promise<string>` | Must `await` ⚠️ |

### Step 3: Update All Views

Change every form from Rails UJS events to Turbo events:

```diff
  <%# Before: Rails UJS %>
  <%= form_with url: answer_path,
-               data: { action: 'ajax:success->result#update' } %>
+               data: { action: 'turbo:before-fetch-response->result#update' } %>
```

**This is non-negotiable.** You must update **every single form** that uses JavaScript event handlers. Miss one, and you'll have silent failures.

---

## Real-World Example: Submit Button Controller

Here's a complete before/after for our submit button controller:

### Before (Rails UJS)

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

### After (Turbo)

```javascript
// app/frontend/controllers/result_controller.js
import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = ['form']
  
  update(event) {
    event.preventDefault()  // Stop Turbo from processing
    
    const code = event.detail.fetchResponse.response.status
    
    if (code === 202) {  // All questions answered
      this.formTarget.disabled = false
      this.formTarget.querySelectorAll('[type="submit"]').forEach(submit => {
        submit.disabled = false
      })
      console.log('✓ All questions answered - submit button enabled')
    } else if (code === 201) {
      console.log('✓ Answer saved - waiting for more answers')
    }
  }
}
```

```slim
/ app/views/user_lessons/_1_introduction.html.slim
= form_with url: answer_user_lesson_path(@user_lesson),
            data: { action: 'turbo:before-fetch-response->result#update' }
```

**Key changes:**
- Event: `ajax:success` → `turbo:before-fetch-response`
- Added `event.preventDefault()`
- Changed from `event.detail[2].status` to `event.detail.fetchResponse.response.status`
- Removed dual-format handling
- Added console logging for debugging

---

## Real-World Example: Content Replacement Controller

### Before (Rails UJS)

```javascript
// app/frontend/controllers/section_controller.js
replace(event) {
  const html = event.detail[0]  // responseText string
  this.element.outerHTML = html
}
```

### After (Turbo)

```javascript
// app/frontend/controllers/section_controller.js
async replace(event) {
  event.preventDefault()
  
  const html = await event.detail.fetchResponse.responseText
  this.element.outerHTML = html
}
```

**Key changes:**
- Made method `async` to use `await`
- Added `event.preventDefault()`
- `await` the `responseText` Promise
- Simplified (no dual-format handling)

---

## The Testing Trap

Our integration tests passed because they tested the happy path:

```ruby
# test/system/take_lesson_test.rb (INSUFFICIENT)
test 'complete lesson' do
  visit lesson_path(@lesson)
  
  # Introduction
  choose 'True'
  click_on 'Submit'
  
  # Article
  5.times { |i| choose "Answer #{i}" }
  click_on 'Submit'
  
  # ... continue through lesson
  
  assert_text 'Congratulations!'
end
```

**What this test missed:**
- ✅ Forms submit successfully
- ✅ Content updates after submission
- ❌ Submit button state transitions (starts disabled, enables when ready)
- ❌ Reset functionality (never clicks Reset buttons)
- ❌ Results display (doesn't verify correct/wrong indicators)

The test verified the *outcome* (lesson completion) but not the *user experience* (button states, feedback, reset functionality).

### The Fix: Comprehensive E2E Tests

```ruby
# test/system/take_lesson_test.rb (COMPREHENSIVE)
test 'take lesson with full UX verification' do
  visit lesson_path(@lesson)
  
  within('div[data-target="lesson.introPart"]') do
    # Verify submit button starts disabled
    submit_button = find('button[type="submit"]')
    assert submit_button.disabled?, 'Submit button should start disabled'
    
    # Answer the question
    choose 'False'
    
    # Wait for AJAX and verify button enables
    sleep 1
    assert !submit_button.disabled?, 'Submit button should enable after answering'
    
    click_on 'Submit'
  end
  
  # Verify results displayed
  within('div[data-target="lesson.introPart"]') do
    assert_text 'Well done!'  # Feedback appears
  end
  
  # ... test article with progressive button enabling
  
  # Test Reset functionality
  within('div[data-controller="highlighter"]') do
    # Complete the exercise
    within('#hq-1') do
      find('span[data-flag="c"]', text: 'even as').click
      click_on 'Check Answer'
      assert_text 'Well done!'
    end
    
    assert_text 'Click Reset to take the activity again'
    
    # Test Reset
    click_on 'Reset'
    
    # Verify questions reset
    within('#hq-1') do
      assert_text 'Which linking phrase in paragraph one shows contrast?'
      assert_no_text 'Well done!'  # Feedback cleared
    end
    
    # Verify can answer again
    within('#hq-1') do
      find('span[data-flag="c"]', text: 'even as').click
      click_on 'Check Answer'
      assert_text 'Well done!'  # Works after reset
    end
  end
end
```

**What this test verifies:**
- ✅ Submit button disabled state
- ✅ Submit button enables when questions answered
- ✅ Results display after submission
- ✅ Reset button clears state
- ✅ Exercise works after reset

**Test results:**
```
2 tests, 112 assertions, 0 failures
```

These tests now catch the exact bugs that slipped into production.

---

## Migration Checklist

When upgrading from Rails UJS to Turbo, use this checklist:

### Phase 1: Audit (Before Changing Anything)

- [ ] Grep for all `ajax:success` listeners in JavaScript
- [ ] Grep for all `ajax:error` listeners in JavaScript  
- [ ] Grep for all `ajax:complete` listeners in JavaScript
- [ ] Find all forms with `data: { action: 'ajax:*' }` in views
- [ ] Document all `Rails.fire()` calls in JavaScript
- [ ] List all controllers that handle form responses

### Phase 2: Update JavaScript Controllers

For each controller that handles form events:

- [ ] Change `ajax:success` → `turbo:before-fetch-response`
- [ ] Change `ajax:error` → `turbo:submit-error`
- [ ] Add `event.preventDefault()` at start of handler
- [ ] Change `event.detail[0]` → `await event.detail.fetchResponse.responseText`
- [ ] Change `event.detail[1]` → `event.detail.fetchResponse.response.statusText`
- [ ] Change `event.detail[2].status` → `event.detail.fetchResponse.response.status`
- [ ] Make methods `async` if using `await`
- [ ] Remove all dual-format handling code
- [ ] Add console logging for debugging

### Phase 3: Update Views

For each form view:

- [ ] Change `data: { action: 'ajax:success->...' }` to `turbo:before-fetch-response->...`
- [ ] Change `data: { action: 'ajax:error->...' }` to `turbo:submit-error->...`
- [ ] Remove `data: { turbo: false }` if added as temporary fix
- [ ] Verify form uses `form_with` (not `form_tag`)

### Phase 4: Update Form Submission Code

- [ ] Replace `Rails.fire()` with `form.requestSubmit()`
- [ ] Replace `$.ajax()` with Fetch API or Turbo
- [ ] Remove `remote: true` from forms (Turbo handles this)

### Phase 5: Testing

- [ ] Write tests for submit button state transitions
- [ ] Write tests for reset functionality
- [ ] Write tests for results/feedback display
- [ ] Test error handling paths
- [ ] Manual QA of all interactive forms
- [ ] Check browser console for Turbo errors

---

## Common Pitfalls and How to Avoid Them

### Pitfall 1: Using `turbo:submit-end` Instead of `turbo:before-fetch-response`

**Wrong:**
```javascript
document.addEventListener('turbo:submit-end', (event) => {
  event.preventDefault()  // Too late! Turbo already processed the response
  const html = await event.detail.fetchResponse.responseText
  this.element.innerHTML = html
})
```

**Error:**
```
Form responses must redirect to another location
```

**Right:**
```javascript
document.addEventListener('turbo:before-fetch-response', (event) => {
  event.preventDefault()  // Perfect timing! Stops Turbo from processing
  const html = await event.detail.fetchResponse.responseText
  this.element.innerHTML = html
})
```

### Pitfall 2: Forgetting to Await Promises

**Wrong:**
```javascript
const html = event.detail.fetchResponse.responseText
this.element.innerHTML = html  // Sets innerHTML to "[object Promise]"
```

**Right:**
```javascript
const html = await event.detail.fetchResponse.responseText
this.element.innerHTML = html  // Sets innerHTML to actual HTML string
```

### Pitfall 3: Incomplete View Updates

**You updated the JavaScript but forgot one form:**

```slim
/ ❌ This form still uses ajax:success - silently fails
= form_with url: answer_path,
            data: { action: 'ajax:success->result#update' }

/ ✅ This form works
= form_with url: submit_path,
            data: { action: 'turbo:before-fetch-response->section#replace' }
```

**Solution:** Grep your views after migration:
```bash
grep -r "ajax:success\|ajax:error\|ajax:complete" app/views/
# Should return 0 results
```

### Pitfall 4: Tests That Don't Match User Flows

**Your test:**
```ruby
click_on 'Submit'
assert_text 'Success'
```

**What it misses:**
- Button state changes
- Reset functionality  
- Error feedback
- Progressive enabling

**Better test:**
```ruby
submit_button = find('button[type="submit"]')
assert submit_button.disabled?

choose 'Answer'
assert !submit_button.disabled?

click_on 'Submit'
assert_text 'Correct!'

click_on 'Reset'
assert submit_button.disabled?  # Reset clears state
```

---

## Alternative Approaches

### Option 1: Turbo Streams (Recommended for New Projects)

Instead of manual content replacement with `preventDefault()`, use Turbo Streams:

**Controller:**
```ruby
def create
  @result = process_answer(params[:answer])
  
  respond_to do |format|
    format.turbo_stream  # Returns turbo-stream response
  end
end
```

**View (create.turbo_stream.erb):**
```erb
<%= turbo_stream.replace "section-intro" do %>
  <%= render partial: "intro_results", locals: { result: @result } %>
<% end %>

<%= turbo_stream.update "submit-button" do %>
  <button type="submit" <%= "disabled" unless @all_answered %>>Submit</button>
<% end %>
```

**Benefits:**
- No `preventDefault()` needed
- No manual HTML replacement
- No Promise handling
- Server-driven UI updates
- Real-time capable (via ActionCable)

**Tradeoffs:**
- Larger refactor from existing code
- Requires dedicated turbo_stream views
- More server round-trips

### Option 2: Keep Manual Handling (Our Choice)

We chose to keep manual content replacement because:
- Smaller migration surface area
- Existing server responses work as-is
- Fine-grained control over UI updates
- No need for real-time features yet

**When to use each:**
- **Turbo Streams:** New projects, real-time features, server-driven UI
- **Manual handling:** Migrating existing UJS code, client-side control

---

## Debugging Tips

### 1. Add Console Logging

```javascript
update(event) {
  console.group('result#update')
  console.log('Event:', event)
  console.log('Detail:', event.detail)
  console.log('Status:', event.detail.fetchResponse.response.status)
  console.groupEnd()
  
  event.preventDefault()
  // ... rest of code
}
```

### 2. Watch Turbo Events

```javascript
// Add to application.js for debugging
document.addEventListener('turbo:before-fetch-response', (event) => {
  console.log('turbo:before-fetch-response', {
    url: event.detail.fetchResponse.response.url,
    status: event.detail.fetchResponse.response.status,
    ok: event.detail.fetchResponse.response.ok
  })
})

document.addEventListener('turbo:submit-end', (event) => {
  console.log('turbo:submit-end', {
    success: event.detail.success,
    formSubmission: event.detail.formSubmission
  })
})
```

### 3. Check Response Headers

```javascript
async replace(event) {
  event.preventDefault()
  
  const response = event.detail.fetchResponse.response
  console.log('Content-Type:', response.headers.get('Content-Type'))
  console.log('Status:', response.status)
  
  const html = await event.detail.fetchResponse.responseText
  console.log('HTML length:', html.length)
  
  this.element.outerHTML = html
}
```

### 4. Verify Event Listeners

Open browser console and check registered listeners:

```javascript
// In browser console
getEventListeners(document)
// Should show turbo:before-fetch-response listeners
```

---

## Performance Considerations

### Before (Rails UJS)

Each form submission:
1. Browser sends AJAX request
2. Server returns HTML partial
3. `ajax:success` fires
4. JavaScript updates DOM

**Network:** 1 request  
**JavaScript events:** 1 event (`ajax:success`)

### After (Turbo)

Each form submission:
1. Browser sends Fetch request
2. Server returns HTML partial  
3. `turbo:submit-start` fires
4. `turbo:before-fetch-request` fires
5. `turbo:before-fetch-response` fires (we handle here)
6. `turbo:submit-end` fires

**Network:** 1 request (same)  
**JavaScript events:** 4 events (more overhead)

**Impact:** Negligible. The extra events fire in microseconds. Turbo's caching and predictive prefetching often make the app *faster* overall.

---

## Key Takeaways

### 1. **Event Timing is Critical**

Use `turbo:before-fetch-response`, not `turbo:submit-end`. The former fires before Turbo processes the response, allowing `preventDefault()` to work.

### 2. **Promises are Everywhere**

`FetchResponse.responseText` and `.responseHTML` are Promises. Always `await` them.

### 3. **Migration Must Be Complete**

You cannot have some forms using Rails UJS and others using Turbo. It's all or nothing. Dual-format code hides bugs.

### 4. **Tests Must Match Reality**

Integration tests should verify the user experience, not just the outcome. Test button states, reset functionality, and error feedback—not just "does it submit?"

### 5. **Console Logging is Your Friend**

Add generous logging during migration. Remove it later if needed, but during migration it's invaluable for debugging silent failures.

---

## Conclusion

Migrating from Rails UJS to Turbo is not a drop-in replacement. The event formats are different, the timing is different, and the expectations are different. But with careful attention to:

- Event timing (`turbo:before-fetch-response`)
- Promise handling (`await responseText`)
- Complete migration (update all forms)
- Comprehensive testing (verify UX, not just outcomes)

...you can successfully migrate without breaking production.

Our migration touched 18 controller files, 8 view files, and required new comprehensive tests. It took time, but the result is a faster, more maintainable application that's ready for Turbo's advanced features like Streams and real-time updates.

**The most important lesson:** Your tests should fail when your users fail. If users can't reset exercises but your tests pass, your tests are testing the wrong things.

---

## Resources

- [Turbo Handbook](https://turbo.hotwired.dev/handbook/introduction)
- [Turbo Events Reference](https://turbo.hotwired.dev/reference/events)
- [FetchResponse API](https://github.com/hotwired/turbo/blob/main/src/http/fetch_response.ts)
- [Stimulus Handbook](https://stimulus.hotwired.dev/handbook/introduction)
- [Our GitHub PR with full migration](https://github.com/reallyenglish/re-n2r/pull/211)

---

**About the Author:** Built at ReallyEnglish, a language learning platform serving thousands of students globally. This migration was completed in June 2026 with comprehensive testing to ensure zero downtime and no user-facing bugs.

**License:** This article is licensed under CC BY-SA 4.0. Code examples are MIT licensed.
