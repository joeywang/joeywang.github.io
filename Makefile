# Jekyll blog (Chirpy) dev commands — uses the repo's locked toolchain via mise.
.PHONY: serve build check check-frontmatter check-links new-post clean

serve: ## Local preview with drafts + live reload (http://localhost:4000)
	mise exec -- bundle exec jekyll serve --drafts --livereload

build: ## Production build into _site
	mise exec -- bundle exec jekyll build

check: check-frontmatter check-links ## All local quality checks

check-frontmatter: ## Validate post front matter (fails on missing title/date)
	mise exec -- bundle exec ruby scripts/check_frontmatter.rb

check-links: build ## Check internal links in the built site
	mise exec -- bundle exec htmlproofer ./_site --disable-external --allow-missing-href --no-enforce-https

new-post: ## Create a draft:  make new-post title=my-post-slug
	@test -n "$(title)" || (echo "usage: make new-post title=my-post-slug" && exit 1)
	@f="_drafts/$$(date +%F)-$(title).md"; touch "$$f"; \
	echo "Created $$f — add front matter + content, preview with 'make serve'"

clean: ## Remove build output
	rm -rf _site .jekyll-cache
