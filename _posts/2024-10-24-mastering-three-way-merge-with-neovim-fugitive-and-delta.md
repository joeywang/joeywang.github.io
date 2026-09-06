---
layout: post
title: "Three-way merge in Neovim with Fugitive and Delta"
description: "Setting up Neovim, Fugitive, and Delta for three-way merges gives you a fast, keyboard-driven way to resolve Git conflicts without leaving the terminal."
date: 2024-10-24 00:00 +0000
categories: [Engineering]
tags: [git, vim, neovim, productivity]
---

<audio controls preload="metadata" src="/assets/audio/mastering-three-way-merge-with-neovim-fugitive-and-delta-summary.ogg">
  Your browser does not support the audio element.
</audio>


Resolving a three-way merge conflict in Git usually means squinting at `<<<<<<<`, `=======`, and `>>>>>>>` markers in a plain text editor, or reaching for a heavyweight GUI diff tool. Neovim with Fugitive and Delta gets you the same three-way view, LOCAL, BASE, REMOTE, in the terminal, driven entirely from the keyboard.

## Setup

Install Delta:

```bash
# macOS
brew install git-delta

# Ubuntu/Debian
apt install git-delta
```

Install Fugitive with your plugin manager:

```lua
-- Lazy.nvim
{ 'tpope/vim-fugitive', cmd = { 'Git', 'G' } }
```

Point Git at Neovim as the merge tool and Delta as the pager, in `~/.gitconfig`:

```ini
[merge]
    tool = nvimdiff
    conflictstyle = diff3

[mergetool "nvimdiff"]
    cmd = nvim -d $LOCAL $REMOTE $MERGED -c '$wincmd w' -c 'wincmd J'

[core]
    pager = delta

[delta]
    navigate = true
    side-by-side = true
    line-numbers = true
    syntax-theme = gruvbox-dark
```

`conflictstyle = diff3` is what gives you the BASE version alongside LOCAL and REMOTE. Without it, Git only shows two sides, and you're left guessing at what changed relative to the common ancestor.

## Working a conflict

```bash
git merge feature-branch
git mergetool
```

Neovim opens LOCAL and REMOTE side by side, with BASE below them and the MERGED result at the bottom. The commands that matter:

```vim
]c              " next conflict
[c              " previous conflict
:diffget //2    " take LOCAL's version
:diffget //3    " take REMOTE's version
:diffupdate     " refresh diff highlighting
:wqa            " save and exit all windows
```

A couple of keymaps make this faster to reach for:

```lua
vim.keymap.set('n', '<leader>gm', ':Git mergetool<CR>')
vim.keymap.set('n', '<leader>gf', ':diffget //2<CR>')  -- take LOCAL
vim.keymap.set('n', '<leader>gj', ':diffget //3<CR>')  -- take REMOTE
```

Once every conflict marker is gone, finish the merge as usual:

```bash
git add .
git commit
```

## Where this breaks down

`diffget`/`diffput` work well when the conflicting hunks are small and cleanly separated. For a large rename-and-restructure conflict, the three-way view still helps you see what happened, but you'll often end up rewriting the file by hand rather than picking sides hunk by hunk. And if Delta's colors don't render, check `echo $TERM` and `set termguicolors` in Neovim before anything else, that's the most common cause.
