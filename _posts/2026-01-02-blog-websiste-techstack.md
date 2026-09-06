---
title: "Choosing a Website Stack for a 1C1G Server"
description: "A comparison of static sites, WordPress, headless CMS, and Node.js CMS options for a 1 vCPU, 1GB RAM server, by memory use and stability."
layout: post
date: 2026-01-02T00:00:00+00:00
draft: false
categories:
    - website
tags: [jekyll, performance, devops]
---
<audio controls preload="metadata" src="/assets/audio/blog-websiste-techstack-summary.ogg">
  Your browser does not support the audio element.
</audio>

Once a 1C1G server is optimized at the OS level, the next question is which website stack to actually run on it. Not all web technologies are equal under resource constraints, and the choice matters more than it would on a bigger box. Here is how the common options compare on memory use, stability, and maintainability.

## 1. Static sites: the best choice for 1C1G

Examples: Hugo, Astro (static output), Jekyll, Hexo.

Pros: no database, no runtime backend, near-zero memory usage, handles traffic spikes without extra work, and a small attack surface.

Cons: the content editing workflow feels less CMS-like, and every change needs a rebuild to publish.

Best for homepages, blogs, landing pages, and documentation sites.

## 2. Static site with a visual editor: the best balance

Publii paired with Nginx runs the visual editor on your local machine and lets the server just serve static files.

Pros: real WYSIWYG editing, zero server-side processing, and almost no maintenance once it's set up.

Cons: editing doesn't happen directly on the server, so a workflow built around SSH access to content won't fit.

This is the most practical setup for a 1C1G server if you want an editor and don't want a database.

## 3. Traditional CMS: WordPress

Pros: a huge plugin ecosystem and an admin interface most people already know.

Cons: PHP and MySQL both carry real memory overhead, there's an ongoing security maintenance burden, and performance is poor without deliberate tuning.

Acceptable only with strict optimization (see the MySQL and PHP-FPM tuning in the previous post). Overkill for a simple homepage.

## 4. Headless CMS with a static frontend

Examples: Hugo with Decap CMS, or a Next.js static export backed by a CMS.

Pros: online editing with a clean separation between content and presentation.

Cons: more setup complexity, and a Git-based workflow can confuse non-technical editors.

## 5. Node.js CMS (Ghost, Strapi)

Pros: modern interfaces, API-driven.

Cons: high memory usage and a database dependency make this a poor fit for 1C1G. Not recommended here.

## Comparison

| Stack | Memory use | Stability | Ease of use | Fits 1C1G |
| ------------- | ------------ | --------- | ----------- | ------------- |
| Static (Hugo) | Very low | Very high | Moderate | Yes |
| Publii | Very low | Very high | High | Yes |
| WordPress | High | Low | High | Only with tuning |
| Headless CMS | Moderate | High | Low | Only with tuning |
| Node CMS | High | Low | Moderate | No |

For a 1C1G cloud server, static-first is not a compromise, it's the right design. Static site for maximum stability, Publii if you want visual editing without giving up that stability, and a carefully optimized WordPress only if you actually need its dynamic features and are willing to maintain it.
