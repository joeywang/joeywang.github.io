---
layout: post
title: "Building a Test Suite: Pyramid, Layers, and What to Skip"
description: "A framework for deciding how much to test: the testing pyramid, layered test responsibility by architecture tier, and what makes test data good."
date: "2025-01-06"
categories: [Engineering]
tags: [testing, rails, javascript, debugging]
---

<audio controls preload="metadata" src="/assets/audio/test-best-practice-summary.ogg">
  Your browser does not support the audio element.
</audio>

A test suite that tries to cover everything is not the same as a good test suite. The real questions are how much testing is enough, whether tests should mirror real usage or hunt for every edge case, and which layer, controller, service, or model, owns which assertion.

## Real usage vs. total coverage

A test suite earns its keep by testing the right things, not by testing everything. Past a point, more coverage buys diminishing returns: fragile, slow pipelines and edge cases that never occur in production, just noise around the tests that matter.

The better order is to start from real usage flows, add coverage for the edge cases and regressions you've actually hit, and use risk to decide where the remaining effort goes, not exhaustiveness.

## The testing pyramid

| Test type      | Speed  | Cost   | Value                    | Volume    |
|-----------------|--------|--------|---------------------------|-----------|
| Unit            | Fast   | Low    | Local correctness         | Many      |
| Integration     | Medium | Medium | Cross-component behavior  | Some      |
| End-to-end / UI | Slow   | High   | User-facing flow          | Very few  |

Keep unit tests abundant and fast, use integration tests where components actually have to cooperate, and reserve end-to-end tests for the paths that matter most to the user.

## What makes a test good

Purposeful test data matters, bending inputs to exercise a specific path is legitimate, but that's different from an unrealistic or over-rigid setup that only exists to make the test pass. A test that's worth keeping asserts behavior rather than implementation, covers the happy path plus the failure and edge cases that are actually plausible, uses parameterization instead of copy-pasted blocks, and is named so that a failure tells you what broke without opening the file.

| Do this                          | Not this                        |
|-----------------------------------|-----------------------------------|
| Test from the user's perspective  | Test internal mechanics only     |
| Purposeful, varied test data      | Random or unclear inputs         |
| Parameterized coverage            | Copy-pasted test blocks          |
| Names that describe intent        | `test_1`, `test_ABC`             |
| Assert behavior and outcomes      | Assert internal state            |

## Where each layer's logic should be tested

In a layered architecture it's easy to end up re-testing the same logic at every level. The rule that keeps that from happening: test logic where it lives, not everywhere it's used.

| Layer      | Responsibility                     | Should test                       |
|------------|-------------------------------------|------------------------------------|
| Model      | Business rules, data integrity      | Validations, scopes, logic methods |
| Service    | Orchestrates business flow          | Use cases, side effects            |
| Controller | Entry point, contract with clients  | Routing, response codes, request validation |

Whether a controller test should mock its service depends on whether that service logic is already tested elsewhere. If it is, mock it and keep the controller test fast and isolated. If it isn't, a mocked controller test is verifying a contract against code nobody has actually tested, which is worse than no test at all.

## Examples across layers

**Unit test (Python, pytest):**

```python
# order_model.py
class Order:
    def __init__(self, items):
        self.items = items

    def total_price(self):
        return sum(item['price'] * item['qty'] for item in self.items)

# test_order_model.py
import pytest
from order_model import Order

def test_total_price():
    items = [{'price': 10, 'qty': 2}, {'price': 5, 'qty': 4}]
    order = Order(items)
    assert order.total_price() == 10*2 + 5*4
```

**Service-level integration test (Node.js, Mocha + Chai):**

```javascript
// service/orderService.js
function createOrder(userId, items) {
  if (!items.length) throw new Error('Cart is empty');
  return { userId, items, status: 'created' };
}

// test/orderService.test.js
const { expect } = require('chai');
const { createOrder } = require('../service/orderService');

describe('Order Service', () => {
  it('should create an order successfully', () => {
    const result = createOrder(1, [{ id: 1, qty: 2 }]);
    expect(result.status).to.equal('created');
  });

  it('should throw error for empty cart', () => {
    expect(() => createOrder(1, [])).to.throw('Cart is empty');
  });
});
```

**Controller test (Rails), mocking the service it depends on:**

```ruby
# orders_controller.rb
class OrdersController < ApplicationController
  def create
    order = OrderService.new.create_order(params[:user_id], params[:items])
    render json: order, status: :created
  rescue => e
    render json: { error: e.message }, status: :unprocessable_entity
  end
end

# spec/controllers/orders_controller_spec.rb
RSpec.describe OrdersController, type: :controller do
  let(:service) { instance_double(OrderService) }

  before do
    allow(OrderService).to receive(:new).and_return(service)
  end

  it "returns 201 when order created" do
    allow(service).to receive(:create_order).and_return({ id: 123, status: "created" })
    post :create, params: { user_id: 1, items: [{ id: 1, qty: 2 }] }
    expect(response).to have_http_status(:created)
  end

  it "returns 422 when order fails" do
    allow(service).to receive(:create_order).and_raise("Cart is empty")
    post :create, params: { user_id: 1, items: [] }
    expect(response).to have_http_status(:unprocessable_entity)
  end
end
```

**End-to-end test (Cypress), for the one flow that has to work:**

```javascript
// cypress/e2e/order_flow.cy.js
describe('Order Checkout Flow', () => {
  it('should complete checkout', () => {
    cy.visit('/shop');
    cy.get('[data-cy=add-to-cart]').click();
    cy.get('[data-cy=checkout]').click();
    cy.get('[data-cy=confirm-order]').click();
    cy.contains('Order Confirmed').should('exist');
  });
});
```

## The principle

None of this requires a framework beyond the pyramid and the layer table above: cover the real usage paths first, put each assertion at the layer where the logic actually lives, and use factories and parameterized tests to keep the suite from rotting into copy-paste. Everything past that, coverage dashboards, tagging slow tests for selective CI runs, is worth doing once the fundamentals hold, not before.
</content>
