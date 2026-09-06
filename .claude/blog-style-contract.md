# Editing contract for joeywang.github.io posts

You are editing published blog posts in place at `/mnt/data/re/joeywang.github.io/_posts/`.
Author: Joey Wang, a senior engineer (Ruby on Rails, PostgreSQL, DevOps/Kubernetes, AI/agent
infrastructure). The blog is his professional presence: it should read as the writing of an
experienced practitioner that a potential consulting client or a strong engineer would trust.

## Hard rules (never break)

1. NEVER rename a file. Never change `date:` in frontmatter. The filename is the URL.
2. NEVER invent anecdotes, incidents, dates, metrics, benchmarks, client/employer names, or
   personal stories that are not already in the post. "Human-sounding" must come from
   directness and concrete technical specificity, not fabricated war stories.
3. Preserve every `<audio ...>...</audio>` block exactly as-is, in its current position.
4. Preserve the technical meaning of all code blocks. You may fix obvious typos/bugs in code
   only when unambiguous. Never touch `#` comment lines inside code fences when adjusting headings.
5. Keep the post's language: Chinese posts stay Chinese, English posts stay English.
6. Keep valid YAML frontmatter (opening and closing `---`) and valid Markdown. Keep `layout:`
   and any Liquid tags as they are.
7. This is an edit, not an expansion. Aim for equal or shorter length. Cutting filler is the
   single most valuable move.
8. Do not add calls-to-action, "contact me", newsletter pitches, or self-promotion. The quality
   of the writing is the pitch.
9. No em dashes in prose. Use commas, colons, or periods.
10. Do not flip a post's spelling system (US vs British). Keep each post internally consistent.

## Frontmatter (SEO)

- `title:`: sharpen it. Front-load the actual topic keyword, be specific and honest.
  Kill inflated patterns: "Mastering...", "Comprehensive Guide", "Ultimate", "Unleashing",
  "Demystifying", "A Deep Dive into..." (plain "X: what Y actually does" style is better).
  Target ≤ 65 characters where possible. Quote the value.
- `description:`: one complete sentence, roughly 140–160 characters, containing the primary
  keyword and the concrete payoff of the post. Never a truncated fragment. Add it if missing.
- `tags:`: 3–6 tags, all lowercase-kebab. Canonical vocabulary (reuse before inventing):
  rails, ruby, postgresql, mysql, redis, sidekiq, docker, kubernetes, devops, ci,
  github-actions, testing, debugging, performance, database, security, linux, networking,
  aws, gcp, ai, llm, agents, mcp, local-llm, hermes, automation, react, javascript, android,
  nginx, ssh, git, jekyll, productivity, career.
  Map old variants: `Rails`/`ruby-on-rails` → rails; `Kubernetes` → kubernetes; `DevOps` → devops;
  `Actions`/`GitHub` (as tag) → github-actions; `postgres` → postgresql; `ai-agents`/`coding-agent` → agents.
- `categories:`: keep if sensible; if missing, add one or two from: Engineering, DevOps, Rails,
  Database, AI, Security, Notes.
- Do not add other keys. Do not add `author:` if absent.

## Body voice (the main work)

Model the voice on Joey's strongest recent writing. Example of the target register:

> A green CI run can still leave me with an uncomfortable question: did we run the right tests?
> The opposite problem is easier to recognise. A pull request runs every test, every time, even
> when the change is a README edit. The feedback loop gets slower, the bill gets larger, and
> eventually somebody starts looking for ways around it. That is how a safety system becomes a
> delivery tax.

Characteristics: first person, plain declaratives, concrete failure modes, honest about
limitations and trade-offs, a clear judgment stated as a judgment ("That is a feature, not an
embarrassment"), no cheerleading.

Remove or rewrite these AI tells wherever they appear:
- Generic scaffolding: an "## Introduction" that restates the title, an "## Conclusion" that
  restates the sections. Open instead with the concrete problem and what it costs; close with
  the actual judgment or lesson, in a couple of sentences (a heading like "The principle" or no
  heading at all is fine). "Key Takeaways" bullet dumps: fold into a short closing paragraph.
- Vocabulary: delve, crucial, robust, seamless, leverage (as verb), landscape, elevate,
  game-changer, "in today's fast-paced world", "whether you're a beginner or an expert",
  "it's important to note", "let's dive in", "Happy coding!".
- Decorative emojis in headings or bullets: remove them.
- Uniform paragraph rhythm: vary sentence length; prefer short sentences; delete filler adverbs
  (very, really, simply, easily, effectively).
- Hedge-everything phrasing: state what is true; qualify only where the qualification is real.

Structure:
- Headings are H2/H3 only, descriptive enough to carry SEO weight. Demote any stray mid-document
  `# ` heading (outside code fences) to `##`.
- Keep useful tables, lists, and code. Cut sections that say nothing (a "Best Practices" list of
  platitudes, for example) or compress them into one pointed paragraph.

## If a post is already good

Some posts (especially mid-2026 onward) already have this voice. For those, make only targeted
edits: frontmatter SEO, tag normalization, a stray banned word, heading fixes. Do not churn
good prose.

## Report format

When done, report one line per file: `<filename>: <light|medium|heavy> — <what changed>`,
plus a final list of anything you noticed but did not fix (suspected factual errors, dead links,
posts that should perhaps be unpublished).
