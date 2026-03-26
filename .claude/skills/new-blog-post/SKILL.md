---
name: new-blog-post
description: Create a new blog post with proper frontmatter and structure
user-invocable: true
disable-model-invocation: true
---

# New Blog Post Creator

Creates a new blog post in `_posts/` with proper frontmatter, structure, and naming convention.

## Workflow

1. **Get post details from user:**
   - Post title (required)
   - Brief description for SEO (1-2 sentences)
   - Tags (suggest common ones if not provided)

2. **Generate filename:**
   - Format: `YYYY-MM-DD-{slug}.md`
   - Use today's date
   - Convert title to lowercase slug (spaces → hyphens, remove special chars)

3. **Create post with template:**

```markdown
---
title: "{TITLE}"
date: {TODAY's date in YYYY-MM-DD format}
author: "Joey Wang"
description: "{DESCRIPTION}"
tags: [{TAGS}]
---

# {TITLE}

{Brief introduction paragraph - leave placeholder for user to fill}

## 🎯 Overview

{Content section - leave placeholder}

## 💡 Key Points

- Point 1
- Point 2
- Point 3

## 🔧 Implementation

{Technical details section - leave placeholder}

## 📊 Best Practices

{Recommendations section - leave placeholder}

## ✨ Conclusion

{Summary section - leave placeholder}
```

4. **Common tags to suggest:**
   - Ruby on Rails
   - Performance
   - Database
   - Backend Engineering
   - DevOps
   - Docker
   - Kubernetes
   - Testing
   - Security
   - JavaScript
   - React
   - PostgreSQL
   - Redis

5. **After creation:**
   - Show the file path
   - Remind user to run: `bundle exec jekyll serve` to preview
   - Open the file for editing

## Example

User: `/new-blog-post "Optimizing Rails Database Queries"`

Creates: `_posts/2026-03-26-optimizing-rails-database-queries.md`

With frontmatter:
```yaml
---
title: "Optimizing Rails Database Queries"
date: 2026-03-26
author: "Joey Wang"
description: "Learn techniques to optimize database queries in Rails applications for better performance"
tags: [Ruby on Rails, Performance, Database, PostgreSQL]
---
```
