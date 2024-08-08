# joeyw.github.io

## Compose

```bash
  draft      # Creates a new draft post with the given NAME
  post       # Creates a new post with the given NAME
  publish    # Moves a draft into the _posts directory and sets the date
  unpublish  # Moves a post back into the _drafts directory
  page       # Creates a new page with the given NAME
  rename     # Moves a draft to a given NAME and sets the title
  compose    # Creates a new file with the given NAME
```

```bash
# new page
bundle exec jekyll page "My New Page"
# new post
bundle exec jekyll post "My New Post"
# or specify a custom format for the date attribute in the yaml front matter
$ bundle exec jekyll post "My New Post" --timestamp-format "%Y-%m-%d %H:%M:%S %z"
```
https://github.com/jekyll/jekyll-compose

## Local
```
bundle exec jekyll serve
```
