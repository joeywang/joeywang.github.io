---
layout: post
title: "The Subtle Sabotage: A Rails 7 `button_to` Tale"
date: 2025-05-12 14:41:26 +0100
categories: [Rails, JavaScript, CSS]
---

It was a Tuesday like any other. Coffee was brewing, code was flowing, and our trusty Rails 6 application was humming along. Then came the upgrade. A leap of faith into the world of Rails 7, promising performance boosts and a host of new features. The transition was surprisingly smooth, or so I thought. The calm before the storm.

### The Mystery of the Unstyled Button

The first sign of trouble was subtle. A "Delete" button, once a fiery red beacon of destructive potential, now sat bland and unassuming, a plain default button. I delved into the stylesheet, a place I hadn't needed to visit for this particular button in years. The CSS was straightforward:

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

A quick inspection of the browser's developer tools revealed the culprit. In Rails 6, this `button_to` rendered a simple `<input type="submit">` tag with the class "delete-button". Easy to target, easy to style.

But in Rails 7, the landscape had changed. The same `button_to` helper now generated a more complex structure: a `<form>` element wrapping a `<button>` element.

```html
<form class="button_to" method="post" action="/items/1">
  <input type="hidden" name="_method" value="delete" autocomplete="off">
  <button class="delete-button" type="submit">Delete</button>
</form>
```

Our CSS was targeting a class on the button itself, which was correct. However, the new parent `<form>` tag, a block-level element, was disrupting the layout, causing the button to appear on a new line and lose its intended inline styling with other buttons.

**The Fix:** The solution was twofold. First, to address the layout issue, we could have used CSS to make the form inline. However, a more Rails-idiomatic solution was to use the `:form_class` option in the `button_to` helper to control the wrapping form's styling. For more complex scenarios, you can directly apply classes to the form and target them in your CSS.

More importantly for the visual styling, the issue wasn't the CSS selector itself, but the unexpected structural change. The class was still being applied to the button. The real "aha\!" moment was understanding that `button_to` now creates a mini-form around the button.

### The Silent Treatment: When JavaScript Gives Up

With the styling mystery solved, a more sinister problem emerged. Our "Delete" button was supposed to trigger a JavaScript confirmation dialog before proceeding. This was handled by a simple JavaScript snippet that listened for a click on the button.

In our Rails 6 world, with Rails-UJS, this worked flawlessly. The JavaScript looked something like this, targeting the class on the input:

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

In Rails 7, this JavaScript failed silently. The confirmation dialog never appeared. The reason, once again, lay in the rendered HTML. Rails 7 and its default integration with Turbo have a different way of handling confirmation dialogs.

The `data-confirm` attribute that Rails-UJS relied on is now `data-turbo-confirm`. And for it to work with `button_to`, it needs to be placed on the `form` element, not the `button` itself.

**The Fix:** The modern Rails 7 way to handle this is to embrace Turbo's conventions. The `button_to` helper should be updated to pass the confirmation message in a `form` hash:

```erb
<%= button_to "Delete", item_path(@item), method: :delete, form: { data: { turbo_confirm: "Are you sure?" } }, class: "delete-button" %>
```

This simple change generates the correct `data-turbo-confirm` attribute on the wrapping `<form>` tag, allowing Turbo to intercept the form submission and display the confirmation dialog. Our custom JavaScript for this simple confirmation was no longer needed.

### The Moral of the Story

The transition from Rails 6 to 7 brought significant improvements, but also subtle breaking changes in familiar helpers like `button_to`. The shift from a simple input to a form-wrapped button, and the move from Rails-UJS to Turbo, can easily trip up unsuspecting developers.

This experience was a valuable lesson in the importance of not just reading the release notes, but also inspecting the generated HTML when things don't behave as expected. What appears to be a bug in your code might just be a new, and often better, way of doing things in the latest version of your favorite framework. The devil, as they say, is in the details—or in this case, the DOM.
