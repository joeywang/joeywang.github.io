# joeywang.github.io - Technical Blog

Jekyll-based blog with Chirpy theme, deployed to GitHub Pages.

## Quick Start

```bash
# Install dependencies
bundle install

# Run local server (http://localhost:4000)
bundle exec jekyll serve

# Build for production
JEKYLL_ENV=production bundle exec jekyll build
```

## 🚀 Automated Blog Workflow

**You focus on:** Topic, ideas, opinions (5 minutes)
**System handles:** Writing, formatting, social media, publishing

### Quick Workflow

```bash
# When you have an idea
/blog-idea "Your topic and angle"

# When ready to write
/blog-workflow
# Answer 6 questions (5 min)
# System generates humanized post + social media
```

**Complete guide:** See [BLOG-WORKFLOW.md](BLOG-WORKFLOW.md)

---

## Creating Blog Posts

```bash
# Use skill (after creating the skill)
/new-blog-post "Your Post Title"

# Or manually create in _posts/
# Format: YYYY-MM-DD-title-slug.md
```

**Required frontmatter**:
```yaml
---
title: "Post Title"
date: YYYY-MM-DD
author: "Joey Wang"
description: "Brief description for SEO"
tags: [Ruby on Rails, Performance, ...]
---
```

## Writing Style

Full contract: [.claude/blog-style-contract.md](.claude/blog-style-contract.md). The short version:

- First person, direct, concrete. Open on the actual problem and what it costs; close with the judgment or lesson, not a "Conclusion" that restates the sections.
- Use H2 (##) and H3 (###) for sections; never an H1 in the body (Chirpy renders the title as H1)
- No decorative emojis in headings or bullets
- No AI boilerplate: delve, crucial, robust, seamless, landscape, "In today's...", "Key Takeaways" dumps, "Happy coding!"
- No em dashes; use commas, colons, or periods
- Never invent anecdotes, metrics, or case studies; specificity comes from the real technical content
- Include code examples with syntax highlighting
- Frontmatter: specific title ≤65 chars (no "Mastering/Comprehensive Guide"), 140–160 char description, 3–6 lowercase-kebab tags

**Common tags** (lowercase-kebab): rails, ruby, postgresql, redis, sidekiq, docker, kubernetes, devops, ci, github-actions, testing, debugging, performance, database, security, ai, llm, agents
**Categories** (1–2 per post): Engineering, DevOps, Rails, Database, AI, Security, Notes

## GitHub Actions

- **jekyll.yml**: Builds and deploys to GitHub Pages on push to main
- Social posting is handled manually/outside GitHub Actions. Do not add automated social-post generation back to the repo.

## Theme: Chirpy

- Pagination: 5 posts per page
- Comments: Enabled by default
- TOC: Auto-generated for all posts
- Syntax highlighting: Rouge

## Gotchas

- Don't edit `Gemfile.lock` manually - run `bundle update` instead
- GitHub Actions uses Ruby 3.4, keep consistent
- Static files in `static/` are included via config
