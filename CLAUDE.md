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

- Use H2 (##) and H3 (###) for sections
- Add relevant emojis (🎯, 💡, 🔧, 📊, ✨)
- Include code examples with syntax highlighting
- End with key takeaways and conclusion

**Common tags**: Ruby on Rails, Performance, Database, Backend Engineering, DevOps, Docker, Testing, Security

## GitHub Actions

- **jekyll.yml**: Builds and deploys to GitHub Pages on push to main
- **generate-social-posts.yml**: Auto-generates social media posts (logs only, manual posting)

## Theme: Chirpy

- Pagination: 5 posts per page
- Comments: Enabled by default
- TOC: Auto-generated for all posts
- Syntax highlighting: Rouge

## Gotchas

- Don't edit `Gemfile.lock` manually - run `bundle update` instead
- GitHub Actions uses Ruby 3.4, keep consistent
- Static files in `static/` are included via config
