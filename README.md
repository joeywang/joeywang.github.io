# Repository Structure and Guidelines for AI Agents

This document provides guidance for AI agents working with this Jekyll-based blog repository.

## Repository Structure

- **Root directory**: Contains main configuration files and top-level pages
- **`_posts/`**: All blog posts in Markdown format with date prefixes (YYYY-MM-DD-title.md)
- **`_layouts/`**: Jekyll layout templates
- **`_data/`**: Data files used by the site
- **`_tabs/`**: Tab navigation pages
- **`assets/`**: Static assets (CSS, JS, images)
- **`static/`**: Additional static content

## Blog Post Format

All blog posts follow this structure in `_posts/`:

```markdown
---
title: "Your Post Title"
date: YYYY-MM-DD
author: "Joey Wang"
description: "Brief description of the post"
tags: [Tag1, Tag2, Tag3]
---

# Main Title

Your content here...

## Section Headings

Use H2 (##) and H3 (###) for sections, with emoji icons where appropriate.

### Code Examples

Use proper syntax highlighting:

```ruby
# Your code here
```

### Links and References

- Use relative links within the site
- Absolute URLs for external references
```

## Naming Convention

- File names: `YYYY-MM-DD-descriptive-title.extension`
- Use lowercase, hyphens as separators
- Extension: `.markdown` or `.md`

## Common Tags

Frequently used tags include:
- Ruby on Rails, Performance, Database, Backend Engineering
- DevOps, Docker, Kubernetes
- Testing, Security
- JavaScript, React

## Technical Configuration

- Jekyll theme: jekyll-theme-chirpy
- Posts are paginated (5 per page by default)
- Comments enabled for all posts
- Table of contents enabled by default
- Syntax highlighting with Rouge

## Writing Style Guidelines

1. **Structure**: Use H1 for main title, H2/H3 for sections
2. **Emojis**: Use relevant emojis to enhance readability
3. **Code**: Always use proper syntax highlighting
4. **Examples**: Include practical, real-world examples
5. **Performance**: When writing about technical topics, include benchmarks/comparisons where relevant
6. **Best Practices**: Always include a section on best practices
7. **Conclusion**: End with a summary/final thoughts section

## File Extensions

- Blog posts: `.markdown` or `.md`
- Layout files: `.html`, `.md`
- Configuration: `_config.yml`

## Important Configuration Files

- `_config.yml`: Main Jekyll configuration, site settings, and build options
- `Gemfile`: Ruby dependencies for the Jekyll site
- `mise.toml`: Tool version management file

## Development Workflow for Agents

1. Check existing posts in `_posts/` for format consistency
2. Use consistent tagging based on existing patterns
3. Follow the frontmatter format with title, date, author, description, and tags
4. Use similar writing style to existing content
5. Test any code examples provided to ensure they're accurate
6. Add the post to git and create a commit with a descriptive message

## Common Technical Topics Covered

Based on existing posts, common topics include:
- Ruby on Rails optimization and best practices
- Database performance (PostgreSQL, Redis)
- DevOps practices (Docker, Kubernetes)
- Performance optimization techniques
- Testing strategies
- System administration
- Backend engineering patterns