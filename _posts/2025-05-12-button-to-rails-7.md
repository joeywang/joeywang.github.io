---
layout: post
title: "How button_to Changed in Rails 7 (and Broke Our CSS)"
description: "Rails 7's button_to wraps a form around the button instead of rendering a plain input, which silently breaks existing CSS selectors and JavaScript click handlers."
date: 2025-05-12 14:41:26 +0100
categories: [Rails]
tags: [rails, javascript, css, debugging]
---

<audio controls preload="metadata" src="/assets/audio/button-to-rails-7-summary.ogg">
  Your browser does not support the audio element.
</audio>

After upgrading an application from Rails 6 to Rails 7, a "Delete" button lost its red background, and its JavaScript confirmation dialog stopped firing. Both bugs traced back to the same cause: `button_to` renders different HTML now.

## The Mystery of the Unstyled Button

The first sign of trouble was a "Delete" button that used to be a solid red, now sitting as a plain default button. The CSS was straightforward:

```css
.delete-button {
  background-color: #dc3545;
  color: white;
  /* ... other styles */
}
```

The `button_to` helper in our Rails 6 view looked like this:

```erb
<%= button_to "Delete", item_path(@item), method: :delete, class: "delete-button" %>
```

A quick look at the browser's developer tools revealed the cause. In Rails 6, this `button_to` rendered a simple `<input type="submit">` tag with the class "delete-button". Easy to target, easy to style.

In Rails 7, the same `button_to` helper generates a more complex structure: a `<form>` element wrapping a `<button>` element.

```html
<form class="button_to" method="post" action="/items/1">
  <input type="hidden" name="_method" value="delete" autocomplete="off">
  <button class="delete-button" type="submit">Delete</button>
</form>
```

Our CSS was targeting a class on the button itself, which was correct. The problem was the new parent `<form>` tag: a block-level element that disrupted the layout, pushing the button onto its own line and breaking its inline styling with other buttons.

**The fix:** Use CSS to make the form inline, or, more idiomatically, use the `:form_class` option on `button_to` to control the wrapping form's styling directly. The class was still applied to the button all along; the actual change was structural. `button_to` now wraps every button in its own mini-form.

## The Silent Treatment: When JavaScript Gives Up

With the styling fixed, a second problem showed up. The "Delete" button was supposed to trigger a JavaScript confirmation dialog before proceeding, handled by a small script listening for clicks on the button.

Under Rails 6 with Rails-UJS, this worked. The JavaScript looked something like this, targeting the class on the input:

```javascript
document.addEventListener('DOMContentLoaded', () => {
  const deleteButton = document.querySelector('.delete-button');
  if (deleteButton) {
    deleteButton.addEventListener('click', (event) => {
      if (!confirm("Are you sure?")) {
        event.preventDefault();
      }
    });
  }
});
```

In Rails 7, this JavaScript failed silently, and the confirmation dialog never appeared. The reason, again, was the rendered HTML: Rails 7's default Turbo integration handles confirmation dialogs differently.

The `data-confirm` attribute that Rails-UJS relied on is now `data-turbo-confirm`. For it to work with `button_to`, it needs to be placed on the `form` element, not the `button` itself.

**The fix:** pass the confirmation message through the `form` hash instead:

```erb
<%= button_to "Delete", item_path(@item), method: :delete, form: { data: { turbo_confirm: "Are you sure?" } }, class: "delete-button" %>
```

This generates the correct `data-turbo-confirm` attribute on the wrapping `<form>` tag, so Turbo intercepts the submission and shows the confirmation dialog. The custom JavaScript was no longer needed.

Rails 6 to 7 brought a genuine shift in `button_to`: a form-wrapped button instead of a plain input, and Turbo instead of Rails-UJS. Both changes are reasonable on their own, but they break existing CSS and JavaScript silently. When a helper stops behaving the way it used to, check the rendered HTML before assuming your own code broke.
