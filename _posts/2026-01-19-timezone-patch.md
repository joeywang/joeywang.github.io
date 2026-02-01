---
layout: post
title: "Time Zone Patch: Solving the Asia/Rangoon Postgres Error in Alpine Linux"
date: 2026-01-19
categories: ["Alpine Linux", "Docker", "Postgres"]
---

# When Time Zones Vanish: Solving the Asia/Rangoon Postgres Error in Alpine Linux

If you recently updated your Docker images and were greeted by a `PG::InvalidParameterValue: ERROR: time zone "Asia/Rangoon" not recognized`, you aren't alone. It’s a classic case of infrastructure evolving faster than application data.

## The Root Cause: Why did it break?

In 1989, Rangoon was renamed **Yangon**. For decades, the IANA time zone database kept `Asia/Rangoon` as a "link" (an alias) to `Asia/Yangon`.

However, modern minimalist distributions like **Alpine Linux** have started splitting their `tzdata` package. To keep images small, they moved legacy aliases into a separate, optional package called `tzdata-backward`. If your database contains the old string and your OS doesn't have the "backward" links, PostgreSQL—which relies on the OS for time zone definitions—will fail.

## The Strategy: Defense in Depth

The best practice for solving this isn't just a "hotfix." It’s a layered approach that makes your application **standard-compliant** and **environmentally resilient**.

---

### Layer 1: The Infrastructure "Safety Net"

If you need to fix production **immediately**, you must restore the legacy aliases at the OS level.

#### For Alpine Linux (Dockerfile)

Add the `tzdata-backward` package explicitly:

```dockerfile
# Add tzdata-backward to support legacy IANA names
RUN apk add --no-cache tzdata tzdata-backward

```

#### For Debian/Ubuntu (Dockerfile)

Ensure `tzdata` is installed in non-interactive mode:

```dockerfile
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y tzdata

```

---

### Layer 2: Application-Level Normalization

Relying on the OS for legacy support is technical debt. The "clean" way is to normalize data before it hits your database.

#### The Normalizer Concern

Create a reusable concern for your models (e.g., `User` or `Account`):

```ruby
# app/models/concerns/time_zone_normalizer.rb
module TimeZoneNormalizer
  extend ActiveSupport::Concern

  ZONE_MAPPINGS = {
    'Asia/Rangoon'  => 'Asia/Yangon',
    'Asia/Katmandu' => 'Asia/Kathmandu',
    'Asia/Calcutta' => 'Asia/Kolkata'
  }.freeze

  included do
    before_validation :normalize_time_zone
  end

  private

  def normalize_time_zone
    if respond_to?(:time_zone) && ZONE_MAPPINGS.key?(time_zone)
      self.time_zone = ZONE_MAPPINGS[time_zone]
    end
  end
end

```

---

### Layer 3: The Data Migration

Clean up your existing records so your database logic (like `AT TIME ZONE` queries) doesn't have to deal with deprecated strings.

```ruby
class NormalizeLegacyTimeZones < ActiveRecord::Migration[7.0]
  def up
    mappings = { 'Asia/Rangoon' => 'Asia/Yangon', 'Asia/Katmandu' => 'Asia/Kathmandu' }

    mappings.each do |old_zone, new_zone|
      execute <<-SQL
        UPDATE users SET time_zone = '#{new_zone}' WHERE time_zone = '#{old_zone}';
      SQL
    end
  end
end

```

---

### Layer 4: Automated Verification (The "Sanity Check")

Prevent regressions by adding a test that ensures all time zones in your database are actually valid in your current environment.

```ruby
# spec/models/user_spec.rb
it "contains only time zones recognized by the system" do
  distinct_zones = User.pluck(:time_zone).compact.uniq
  
  invalid_zones = distinct_zones.reject do |zone|
    ActiveSupport::TimeZone[zone].present? rescue false
  end

  expect(invalid_zones).to be_empty, "Found unrecognized time zones in DB: #{invalid_zones}"
end

```

---

## Conclusion: Build for Portability

By moving the mapping logic into your application, you gain two major benefits:

1. **Portability:** Your app will run on any OS, even those with zero legacy time zone support.
2. **Predictability:** You are no longer at the mercy of `tzdata` maintainers.

Don't just fix the error—fix the architecture. Standardizing on current IANA names is a small step that prevents major headaches during your next infrastructure upgrade.
