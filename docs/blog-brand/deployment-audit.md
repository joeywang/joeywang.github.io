# Blog deployment and publishing audit

Observed at 2026-09-08 23:41–23:45 UTC. This is a read-only investigation. No Pages, Cloudflare, DNS, repository, or deployment setting was changed.

## Executive summary

There are now two independently served versions of the site:

- `https://joeywang.github.io` serves the Jekyll build from this repository at `88920a64bb6531ef6b8f6249b9aadffe4b5557e4`.
- `https://joeyw.reallyenglish.com` is a CNAME for `blog-dl2.pages.dev` and serves an Astro build from the separate `joeywang/joeyw-astro` repository. Cloudflare reports its latest successful production deployment as Astro commit `40dc08b7c3fc1f08321172abb542bbe58db81b88`.

This explains the publishing gap. A merge to this repository's `main` updates GitHub Pages, but it does not update the custom domain. The September 6 redirect and 404 observations are no longer current: both origins now return 200 for the audited pages, and the GitHub hostname no longer redirects to the custom hostname. The remaining problem is split ownership, duplicate public content, and invalid discovery metadata on the custom origin.

Do not continue the dependent brand-copy cards until Joey chooses the canonical origin and the repository that owns published content.

## Source and revision evidence

### Jekyll repository and GitHub Pages

- Local branch: `overnight/todo-0201-map-the-live-deployment-and-publishing-gap`.
- Local HEAD: `88920a64bb6531ef6b8f6249b9aadffe4b5557e4`.
- Fetched `origin/main`: `88920a64bb6531ef6b8f6249b9aadffe4b5557e4`.
- GitHub Pages API: workflow build type, source `main` at `/`, no custom domain, HTTPS enforced, public URL `https://joeywang.github.io/`.
- GitHub Actions run [34100969489](https://github.com/joeywang/joeywang.github.io/actions/runs/34100969489) checked out this SHA, passed frontmatter, Jekyll build, internal-link check and artifact upload, then successfully deployed that artifact to the `github-pages` environment on 2026-09-07.
- GitHub deployment `6304921365` records the same SHA and a successful `github-pages` environment URL.
- The live GitHub response identifies `server: GitHub.com` and `last-modified: Mon, 07 Sep 2026 08:32:15 GMT`. Its description, homepage introduction, About page, Consulting page and audited post agree with source at this revision.

The workflow separates three stages:

1. `actions/checkout` obtains the event revision (`.github/workflows/jekyll.yml:36-37`).
2. Jekyll builds it, html-proofer checks it, and `upload-pages-artifact` stores the generated `_site` (`.github/workflows/jekyll.yml:44-60`).
3. `actions/deploy-pages` publishes the uploaded artifact to GitHub Pages (`.github/workflows/jekyll.yml:62-72`).

A successful checkout or build is not deployment evidence. Run 34100969489 provides evidence for all three stages at the exact main SHA.

### Pull-request behavior

The workflow runs for both pushes and pull requests, and the deploy job has no event/ref condition (`.github/workflows/jekyll.yml:9-17,62-72`). The GitHub `github-pages` environment currently has a custom branch policy. In observed pull-request run [33764061800](https://github.com/joeywang/joeywang.github.io/actions/runs/33764061800), the build and Pages artifact upload passed, then the deploy job failed before a runner or step started. There is no evidence that this pull request reached serving infrastructure.

The present environment policy prevented that observed deployment, but the workflow still requests a production deployment on pull requests. Repository workflow logic should enforce the release rule rather than depending only on mutable environment policy.

### Custom domain and Astro deployment

- DNS: `joeyw.reallyenglish.com` is a CNAME for `blog-dl2.pages.dev`.
- The live response identifies `server: cloudflare` and contains Astro asset paths such as `/_astro/...`.
- The Cloudflare Pages project is `blog`; its domains are `blog-dl2.pages.dev` and `joeyw.reallyenglish.com`, and its production branch label is `main`.
- Latest successful production deployment: `23d0ba29-cf79-4749-8d65-a51d9f7fecfd`, created 2026-09-07 08:52:41 UTC, ad-hoc trigger, Astro commit `40dc08b7c3fc1f08321172abb542bbe58db81b88` (`Astro split deployment`).
- Separate repository `joeywang/joeyw-astro` currently has `main` at `b48d183b8ebacb3a1cd7faf8eb10361d63d54cf0`. Its current CI builds and checks the site but no longer deploys it (`.github/workflows/ci.yml:1-40`). Therefore even that repository's current main is newer than the custom-domain deployment.

The Astro source is a committed migration, not a live read of this Jekyll repository. Its migration command copies content from Jekyll into Astro (`package.json:16`), while the deployed page assets and copy come from the resulting Astro repository. Changes made after migration remain separate unless content is migrated again and Astro is explicitly deployed.

## Public URL audit

All requests below were made on 2026-09-08 UTC with redirects followed.

| Requested URL | Final URL | Status | Live canonical |
|---|---|---:|---|
| `https://joeywang.github.io/` | same | 200 | `https://joeywang.github.io/` |
| `https://joeywang.github.io/about/` | same | 200 | `https://joeywang.github.io/about/` |
| `https://joeywang.github.io/consulting/` | same | 200 | `https://joeywang.github.io/consulting/` |
| `https://joeywang.github.io/posts/when-a-green-deployment-still-serves-a-500/` | same | 200 | same GitHub URL |
| `https://joeywang.github.io/sitemap.xml` | same | 200 | not applicable |
| `https://joeywang.github.io/robots.txt` | same | 200 | not applicable |
| `https://joeyw.reallyenglish.com/` | same | 200 | `https://joeywang.github.io/` |
| `https://joeyw.reallyenglish.com/about/` | same | 200 | `https://joeywang.github.io/about/` |
| `https://joeyw.reallyenglish.com/consulting/` | same | 200 | `https://joeywang.github.io/consulting/` |
| `https://joeyw.reallyenglish.com/posts/when-a-green-deployment-still-serves-a-500/` | same | 200 | same path on the GitHub hostname |
| `https://joeyw.reallyenglish.com/sitemap.xml` | same | 200 | not applicable |
| `https://joeyw.reallyenglish.com/robots.txt` | same | 200 | not applicable |

`http://joeywang.github.io/` redirects once to `https://joeywang.github.io/`, not to the custom hostname.

### Content assertions

- GitHub Pages is the current Jekyll/Chirpy site. The homepage contains “Practical notes on software, AI, and the systems around them”; About contains “I build software that can be operated with confidence”; Consulting contains the current Rails/LMS audit offer; and the incident post contains the expected title and body.
- The custom origin is the Astro site. It has Astro assets and a solutions-first/full-stack presentation. Its About copy says Joey works across “DevOps and reliability, AI-native engineering, and full stack development,” which differs from `about.markdown:12-23` in this repository.
- Both origins now contain the Consulting page and incident post. The earlier 404s have been resolved, but by creating a second serving path rather than by making one deployment authoritative.

### Sitemap and robots contradictions

The GitHub origin is internally consistent:

- `/robots.txt` points to `https://joeywang.github.io/sitemap.xml`.
- `/sitemap.xml` returns 200 and uses the GitHub hostname with normal single-slash paths.

The custom origin is inconsistent:

- Every audited HTML canonical points to the GitHub hostname because Astro hard-codes that origin in `astro.config.mjs:9` and `src/config/site.ts:6`.
- `/robots.txt` points to `https://joeywang.github.io/sitemap-index.xml`.
- `https://joeywang.github.io/sitemap-index.xml` returns 404.
- The custom origin's `/sitemap-index.xml` returns 200, but it points to `https://joeywang.github.io/sitemap-0.xml`; that GitHub URL returns 404. The corresponding file exists only on the custom origin.
- The legacy `/sitemap.xml` still returns 200 on the custom origin, but its entries use the GitHub hostname and doubled path separators, for example `https://joeywang.github.io//posts/register-function/`.

The custom origin therefore serves crawlable duplicate pages while telling search engines that another origin is canonical, and its advertised sitemap chain crosses to missing files on that other origin.

## Smallest remediation and decision gate

### Decision required

Joey must choose one canonical public origin and one publishing repository:

1. `joeyw.reallyenglish.com` backed by `joeywang/joeyw-astro`; or
2. `joeywang.github.io` backed by this Jekyll repository, or by completing the intended Astro replacement on GitHub Pages.

Do not change canonical URLs, redirects, DNS, Pages domains, or Search Console until this is explicit. Those choices affect indexed URLs and are release decisions.

### Proposed smallest path if the custom domain is canonical

This is the smallest change that matches the currently branded/custom serving infrastructure:

1. In `joeywang/joeyw-astro`, change both `astro.config.mjs:9` and `src/config/site.ts:6` to `https://joeyw.reallyenglish.com`.
2. Change `public/robots.txt:3` to `https://joeyw.reallyenglish.com/sitemap-index.xml`.
3. Build and verify that HTML canonicals, the sitemap index, `sitemap-0.xml`, feed URLs, links, tests and parity checks all use or resolve on the custom origin.
4. Restore an explicit, push-to-main-only deployment procedure for the Astro repository, or document an owner-approved exact-SHA manual release. The current Astro workflow does not deploy.
5. After that release is verified, make `joeywang.github.io` redirect to the custom origin or otherwise remove its duplicate pages from indexing. This final serving change is separate and must preserve every published path.

The Jekyll release guard remains a separate minimal change: add `if: github.event_name == 'push' && github.ref == 'refs/heads/main'` to its deploy job. Pull requests should continue to build and check their artifacts without requesting a production deployment.

### Rollback

- Canonical/configuration rollback: revert only the Astro canonical/robots commit and rebuild.
- Cloudflare release rollback: redeploy the previously verified deployment `23d0ba29-cf79-4749-8d65-a51d9f7fecfd` while preserving DNS and domain bindings; then recheck the six audited custom-domain paths and response metadata.
- Jekyll guard rollback: revert its one workflow commit. This does not alter site content.
- Redirect/cutover rollback: restore the previous serving configuration and verify both origin behavior and the selected canonical before changing discovery tools again.

Do not use a GitHub Pages success as evidence that the custom domain was updated, and do not use a Cloudflare deployment success as evidence that `joeywang.github.io` was updated.

## Unknowns and follow-up gates

- Which domain Joey wants users and search engines to treat as canonical.
- Whether Astro or Jekyll is now the durable source of truth for new posts and page copy.
- Who owns Astro production releases now that its CI does not deploy.
- Whether the two public origins should temporarily coexist during migration, and for how long.
- Search Console ownership, submitted sitemap state, indexed duplicates and traffic were not accessed by this task.
- Interactive browser verification could not run because Chromium is not installed in the worker environment. HTTP, source, generated-markup, DNS, GitHub API and Cloudflare API checks were completed instead. The Astro launch checklist also still records its manual browser checks as pending.

## Acceptance evidence map

- Revisions, final URLs, statuses, canonicals, sitemap domains and observation dates: recorded above.
- Checkout, artifact and serving layers: established from the workflow, exact-SHA run/jobs, GitHub deployment, live headers, DNS and Cloudflare metadata.
- Smallest remediation, exact files, domain decision and rollback: recorded above; no runtime configuration was modified.
- Required six-path audit: completed on the GitHub origin and repeated on the custom origin to expose the split.
- Handoff: only this file is changed. Pending review is the canonical/source-of-truth decision plus a fresh review of the release guards before any PR or deployment.
