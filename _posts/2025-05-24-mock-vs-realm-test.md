---
layout: post
title: "When to Mock and When to Hit the Real Thing in Rails Tests"
description: "A practical breakdown of when to mock external dependencies in Rails tests versus using the real thing, built around the test pyramid, VCR, WebMock, and Pact."
date: 2025-05-24
categories: [Rails]
tags: [rails, testing, debugging, ci]
---
<audio controls preload="metadata" src="/assets/audio/mock-vs-realm-test-summary.ogg">
  Your browser does not support the audio element.
</audio>

Every test suite runs into the same tension: mocking makes tests fast and deterministic, but a suite built entirely on mocks can go green while the real integration is broken. There's no single right answer for when to mock and when to hit the real dependency, but there is a workable strategy: get speed where it counts, and real confidence where it counts more.

## Mocks: Useful, and Easy to Abuse

When you're dealing with external APIs, flaky third-party services, or slow databases, mocking earns its keep.

* **Speed:** No network calls, no external dependencies to wait on. Tests run fast and CI stays cheap.
* **Determinism:** Mocked tests don't fail because some external service had a bad minute. A failure means your code's logic is wrong, not that the network hiccuped.
* **Isolation:** Mocking out the noise lets you test one unit of code at a time.

The failure mode is just as real. Mocks drift: external APIs change, schemas evolve, and a mock sitting untouched keeps simulating a world that no longer exists, until production integration breaks and the tests never caught it. Mocks also hide complexity: your code might pass the wrong header or mishandle a real edge-case error, and a mock built to the happy path won't catch either one. A green suite built on stale or overly generous mocks is not the same thing as a working integration, and that gap is exactly where things break in production.

## The Test Pyramid, Applied to Rails

The test pyramid is still the right starting point for deciding where mocks belong.

### Unit Tests (roughly 70% of the suite)

This is where mocking is appropriate by default. Isolate the method or class under test from everything else.

In Rails terms: this is your model specs. Is `user.authenticate_password` working? Mock the `BCrypt` hashing if you want, but the point is to test the method itself. If your `Product` model calls an `InventoryService`, mock that service entirely. RSpec's `allow(...).to receive(...)`, plus `double`, `instance_double`, and `class_double`, are the standard tools here.

**Model spec with mocking:**
        ```ruby
        # app/models/product.rb
        class Product < ApplicationRecord
          def available_stock
            # This is the external call we want to control
            InventoryService.current_stock(id)
          end
        end

        # spec/models/product_spec.rb
        require 'rails_helper'

        RSpec.describe Product, type: :model do
          describe '#available_stock' do
            let(:product) { create(:product, id: 123) }

            before do
              # We're telling RSpec: "When InventoryService.current_stock is called with this ID,
              # DON'T go to the real service. Just give me 50."
              allow(InventoryService).to receive(:current_stock).with(product.id).and_return(50)
            end

            it 'fetches and returns the available stock from the (mocked) inventory service' do
              expect(product.available_stock).to eq(50)
            end
          end
        end
        ```

### Integration Tests (roughly 20%)

This layer covers components talking to each other: a controller calling a service, which calls a database. Use real components here where you can, with a safety net around external dependencies.

In Rails terms: request specs are the prime candidate. Your API endpoint should hit the real database, but if it calls out to Stripe or another service, that's where VCR or WebMock come in. You're still mocking, but at the network layer, which is a more realistic simulation than a stubbed method call.

**Request spec with VCR:**
        ```ruby
        # config/initializers/vcr.rb (you set this up once)
        VCR.configure do |config|
          config.cassette_library_dir = "spec/vcr_cassettes" # Where your recorded responses live
          config.hook_into :webmock # Integrates with WebMock
          config.allow_http_connections_when_no_cassette = false # Crucial! Fail if you hit real web without a cassette
        end

        # spec/requests/api/v1/products_spec.rb
        require 'rails_helper'

        RSpec.describe 'Products API', type: :request do
          describe 'GET /api/v1/products/:id' do
            let!(:product) { create(:product, id: 123, name: 'Super Widget') }

            # VCR will record the *actual* HTTP call to api.inventory.com the first time.
            # Subsequent runs will replay it, making the test fast and stable.
            it 'returns product details including stock from external service', vcr: { cassette_name: 'inventory_service/product_123_stock_success' } do
              get "/api/v1/products/#{product.id}"

              expect(response).to have_http_status(:ok)
              json_response = JSON.parse(response.body)
              expect(json_response['product']['name']).to eq('Super Widget')
              expect(json_response['stock']).to eq(50) # This '50' comes from the recorded cassette!
            end
          end
        end
        ```

### End-to-End Tests (roughly 10%)

Simulate a real user: click buttons, fill forms, submit data. These hit everything, your database, your frontend JS, and if staging is configured right, real external services or very realistic mock servers. They're slow and more fragile than the layers below, but they confirm the whole stack actually works together.

In Rails terms: system specs, powered by Capybara and a real browser like headless Chrome. Avoid mocking here if you can; the point is to verify the entire stack.

**System spec with Capybara:**
        ```ruby
        # spec/system/product_Browse_spec.rb
        require 'rails_helper'

        RSpec.describe 'Product Browse', type: :system do
          before do
            driven_by(:selenium_chrome_headless) # Or whatever browser driver you use
            # No mocks here, or extremely high-level ones managed by the test environment itself.
            # We're relying on the actual application setup.
          end

          let!(:product) { create(:product, id: 123, name: 'Amazing Gizmo', description: 'Just buy it.') }

          it 'user can browse to a product page and see its details and real-time stock' do
            # This test implies the real InventoryService, or a very accurate mock service
            # running in your test environment, will respond correctly.
            visit product_path(product)

            expect(page).to have_text('Amazing Gizmo')
            expect(page).to have_text('Just buy it.')
            # This '75' should come from the *actual* (or very realistic test setup) external service
            expect(page).to have_text('Available Stock: 75')
          end
        end
        ```

### When to Run Each Suite

| Suite Type | Mocked? | Purpose | Run Frequency |
| :--- | :--- | :--- | :--- |
| Unit tests | Mostly | Instant feedback, CI safety | Every commit/PR |
| Integration tests | Some, via VCR | Component interaction, API contracts | Nightly / staging builds |
| E2E tests | No, full stack | Real-world confidence, user flows | Pre-release / prod |

## Mocking Tools Worth Knowing

* **VCR:** Records real HTTP interactions and replays them. Tests get the actual response body and headers without hitting the network on every run.
* **WebMock:** Lower-level, stubs HTTP requests precisely. Good for specific error conditions or responses you can't easily record.
* **MSW (Mock Service Worker):** For a JavaScript-heavy Rails frontend, mocks API calls in the browser, giving frontend developers a consistent API to work against even when the backend isn't ready.

## Validating Your Mocks

Mocks drift eventually. The way to catch it is to occasionally run the real thing.

Let some integration tests hit the actual external services on a schedule. They'll be slower and may fail when the external service is down, but that's the point: it's an early warning for drift instead of a silent break in production.

**CI configuration for scheduled real runs:**

        ```yaml
        # .github/workflows/ci.yml (Excerpt for GitHub Actions)
        # ...
        jobs:
          test:
            # ...
            steps:
            # ... (setup code)

            - name: Run RSpec (Unit & VCR-enabled Integration)
              run: bundle exec rspec

            # This job runs on a schedule (e.g., daily) to hit real services.
            # Make sure your external services are stable enough for this!
            - name: Run Select Integration Tests against real services (Nightly Health Check)
              if: github.event_name == 'schedule' # Only run on schedule
              env:
                # Custom flag to tell our tests to allow real connections
                ALLOW_REAL_EXTERNAL_CALLS: 'true'
              run: |
                # Run specific specs that deal with external services,
                # ensuring they're not accidentally using VCR for this run.
                bundle exec rspec spec/requests/api/v1/products_spec.rb --tag ~vcr
                # Or run a specific Rake task for these checks
                # bundle exec rake integration:real_service_checks
        ```

        And in your Rails `spec_helper.rb` (or similar):

        ```ruby
        # spec/rails_helper.rb (simplified)
        require 'webmock/rspec'
        require 'vcr'

        RSpec.configure do |config|
          # ...
          if ENV['ALLOW_REAL_EXTERNAL_CALLS'] == 'true'
            WebMock.allow_net_connect! # Let it rip!
            VCR.configure do |vcr_config|
              vcr_config.allow_http_connections_when_no_cassette = true
            end
          else
            WebMock.disable_net_connect!(allow_localhost: true) # Default: No real external calls
          end
          # ...
        end
        ```

## Contract Testing

In a microservices setup, contract testing (Pact, for example) checks that your mock of an API producer matches what the other service actually provides.

Your Rails app, as a consumer, writes a test defining what it expects from an `Order Service`. Pact generates a JSON contract file from that. The `Order Service`, as provider, runs its own tests against that contract, confirming it lives up to what the consumer expects. That closes the gap where "their API changed and broke us" surprises come from.

**Pact consumer spec for a Rails app:**
        ```ruby
        # spec/service_consumers/pact_spec.rb
        require 'pact_helper'
        require 'order_client' # This is *your* Rails app's client for the Order Service

        RSpec.describe OrderClient, pact: true do
          subject { OrderClient.new('http://localhost:1234') } # Pact starts a mock service on this port

          describe '#get_order' do
            before do
              # This describes the interaction: "When our client asks for order 1,
              # the Order Service should give us a 200 with this JSON body."
              order_service
                .given('an order with ID 1 exists')
                .upon_receiving('a request for order ID 1')
                .with(method: :get, path: '/orders/1', headers: {'Accept' => 'application/json'})
                .will_respond_with(
                  status: 200,
                  headers: { 'Content-Type' => 'application/json' },
                  body: { id: 1, total: 10.00, items: [{ name: 'Laptop' }] }
                )
            end

            it 'successfully fetches and parses the order details from the (mocked) Order Service' do
              response = subject.get_order(1)
              expect(response).to eq({ 'id' => 1, 'total' => 10.00, 'items' => [{ 'name' => 'Laptop' }] })
            end
          end
        end
        ```

## Keeping Slow Tests From Becoming the Bottleneck

Real tests are slow by nature, so set timeouts rather than let a stuck dependency or slow query hang CI for an hour; Capybara's `default_max_wait_time` is the relevant knob for system tests. If an external API is occasionally flaky, build retry logic into the application code itself, then have integration tests cover that behavior, rather than letting tests fail on a single bad response from a remote server.

The rough split that works in practice: mock heavily for unit tests and most integration tests, using VCR for realistic HTTP replay and WebMock for precise stubbing. Save the real dependencies for staging and pre-prod, where Capybara system tests and Pact contract checks run against the actual stack. Don't write system tests just because they feel more real: they're slower and more fragile, so most of the coverage should sit in unit and integration tests, with E2E reserved for the critical user journeys. The scheduled CI job that hits real services once a day is cheap insurance against silent drift.

None of this is about hitting a coverage percentage. It's about knowing that a green suite means the code actually works, not that every dependency was mocked into agreeing with it.
