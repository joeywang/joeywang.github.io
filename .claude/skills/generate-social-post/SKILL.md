---
name: generate-social-post
description: Generate Twitter and LinkedIn posts for blog articles
user-invocable: true
disable-model-invocation: true
---

# Social Media Post Generator

Generates ready-to-post content for Twitter and LinkedIn based on blog articles.

## Workflow

1. **Identify target post:**
   - Ask user which post (or default to most recent in `_posts/`)
   - Read the post file to extract metadata and content

2. **Extract information:**
   - Title from frontmatter
   - Description from frontmatter
   - Key points from the post content (scan for bullet points, headings)
   - Generate URL slug from filename

3. **Generate Twitter post:**

**Format** (max 280 characters):
```
🚀 Just published: {TITLE}

{DESCRIPTION or first sentence}

Read more: https://joeywang.github.io/posts/{SLUG}

#{HASHTAG1} #{HASHTAG2} #{HASHTAG3}
```

**Hashtag selection:**
- Based on tags in frontmatter
- Maximum 3 hashtags
- Use camelCase (e.g., #RubyOnRails, #BackendEngineering)
- Common ones: #RubyOnRails #Performance #DevOps #Docker #Testing #PostgreSQL

**Important:** Ensure total length ≤ 280 characters. Truncate description if needed.

4. **Generate LinkedIn post:**

**Format** (detailed, ~500-1000 characters):
```
🚀 New article: "{TITLE}"

{DESCRIPTION - expand to 2-3 sentences}

In this post, I explore {brief summary of what the post covers}.

Key takeaways:
• {Extract or infer 3-4 main points from post content}
• {Point 2}
• {Point 3}
• {Point 4 if relevant}

{Optional: Add a question or call-to-action}

Read the full article: https://joeywang.github.io/posts/{SLUG}

#{HASHTAGS separated by spaces}
```

**Hashtag selection:**
- Based on tags in frontmatter
- Use 5-8 hashtags
- Common ones: #RubyOnRails #BackendEngineering #Performance #DevOps #SoftwareDevelopment #WebDev

5. **Save outputs:**
   - Create `static/twitter-{slug}-post.md` with Twitter content
   - Create `static/linkedin-{slug}-post.md` with LinkedIn content
   - Display both to user for review/editing

6. **Output to user:**
   - Show both posts clearly separated
   - Include character counts
   - Remind user they can edit before posting

## Example

For post `_posts/2024-02-05-share-db-structure.md`:

**Twitter:**
```
🚀 Just published: Designing Microservices with Proper Data Boundaries

Why shared databases are a code smell and how to improve your architecture with clean boundaries and APIs.

Read more: https://joeywang.github.io/posts/share-db-structure

#Microservices #BackendEngineering #SoftwareArchitecture
```
(Character count: 278)

**LinkedIn:**
```
🚀 New article: "Designing Microservices with Proper Data Boundaries: Why Shared Databases Are a Code Smell"

When building microservices, it's tempting to share databases between services for simplicity. But this creates tight coupling, fragile integrations, and hidden data contracts that become technical debt.

In this post, I explore why database sharing is an anti-pattern and how to evolve your architecture with proper boundaries.

Key takeaways:
• Why shared databases create tight coupling between services
• How to design clean APIs and data ownership boundaries
• Event-driven patterns for service communication
• Strategies for migrating from shared to bounded databases

What's your approach to data boundaries in microservices? Let me know in the comments!

Read the full article: https://joeywang.github.io/posts/share-db-structure

#Microservices #BackendEngineering #SoftwareArchitecture #DistributedSystems #APIDesign #EventDriven #DevOps #SoftwareDevelopment
```
(Character count: ~850)

## Notes

- Always read the actual post content to extract accurate key points
- Match the tone of the original post
- Use emojis sparingly and appropriately
- For technical posts, focus on concrete takeaways
- Include a call-to-action for LinkedIn (question, discussion prompt)
