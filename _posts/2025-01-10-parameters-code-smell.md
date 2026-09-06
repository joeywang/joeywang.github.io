---
layout: post
title: "5 Parameter Code Smells and How to Refactor Them"
description: "Five parameter-related code smells, from boolean flags to long argument lists, and the refactor that turns each function into one that does one thing."
date: "2025-01-10"
categories: [Engineering]
tags: [python, refactoring, debugging]
---

<audio controls preload="metadata" src="/assets/audio/parameters-code-smell-summary.ogg">
  Your browser does not support the audio element.
</audio>

How a function's parameters are designed says a lot about whether the function does one thing or several. Five patterns show up often enough to be worth naming, and each has a refactor that fixes it directly.

## 1. Flag parameters (the boolean trap)

A boolean parameter that branches the function's behavior means the function does two different things under one name.

```python
def calculate_price(books, special_edition=False):
    if special_edition:
        return len(books) * 20  # Special edition price
    return len(books) * 10  # Regular price
```

Split it into two functions instead:

```python
def calculate_regular_price(books):
    return len(books) * 10

def calculate_special_edition_price(books):
    return len(books) * 20
```

Each function now has one job, is easier to test in isolation, and doesn't hide a branch inside its body.

## 2. Null-driven behavior

A function whose behavior depends on whether a parameter is `None` has the same problem as the flag parameter, just with `None` standing in for the flag.

```python
def process_order(order_id, user=None):
    if user:
        if not user.is_active:
            raise Exception("Inactive user.")
        print(f"Processing order {order_id} for {user.name}")
    else:
        raise Exception("User is required.")
```

Separate the cases:

```python
def process_order_with_user(order_id, user):
    if not user.is_active:
        raise Exception("Inactive user.")
    print(f"Processing order {order_id} for {user.name}")

def process_order_without_user(order_id):
    raise Exception("User is required.")
```

## 3. Duplicate information in parameters

This one shows up during a migration: a new structured parameter is introduced, but the old individual parameters stay accepted too, so the same information can arrive two ways.

```python
def calculate_price(copies=None, discount=None, purchases=None):
    if purchases:
        copies = purchases.copies
        discount = purchases.discount

    if copies is None or discount is None:
        raise ValueError("Missing required parameters.")

    return copies * (100 - discount) / 100
```

Prefer the new structured parameter, and deprecate the old ones explicitly rather than silently supporting both indefinitely:

```python
import warnings

def calculate_price(purchases=None, copies=None, discount=None):
    if purchases:
        copies = purchases.copies
        discount = purchases.discount
    else:
        warnings.warn(
            "Passing copies and discount separately is deprecated. Use purchases instead.",
            DeprecationWarning
        )

    if copies is None or discount is None:
        raise ValueError("Missing required parameters.")

    return copies * (100 - discount) / 100
```

## 4. Overloaded parameters

A parameter that accepts more than one type or format pushes type-checking into the function body and makes the calling contract ambiguous.

```python
def get_discount_rate(customer):
    if isinstance(customer, int):  # Customer ID
        return fetch_discount_by_id(customer)
    elif isinstance(customer, str):  # Customer name
        return fetch_discount_by_name(customer)
    else:
        raise ValueError("Invalid customer format.")
```

Give each input shape its own function:

```python
def get_discount_by_id(customer_id):
    return fetch_discount_by_id(customer_id)

def get_discount_by_name(customer_name):
    return fetch_discount_by_name(customer_name)
```

## 5. Long parameter lists

Past three or four parameters, a function signature stops being something you can call correctly from memory.

```python
def create_user(first_name, last_name, email, phone, age, city, country):
    return {
        "first_name": first_name,
        "last_name": last_name,
        "email": email,
        "phone": phone,
        "age": age,
        "city": city,
        "country": country
    }
```

Group the related fields into one object:

```python
from collections import namedtuple

User = namedtuple('User', ['first_name', 'last_name', 'email', 'phone', 'age', 'city', 'country'])

def create_user(user):
    return user._asdict()
```

## The pattern behind all five

Every one of these smells is a function quietly doing more than one job and using its parameter list to hide it, a flag, a null check, a duplicate field, a type check, or just too many arguments to track. The fix is almost always the same: split by responsibility, or group related data into a single object. Neither is a big refactor, but both make the function's actual contract visible at the call site instead of buried in its body.
</content>
