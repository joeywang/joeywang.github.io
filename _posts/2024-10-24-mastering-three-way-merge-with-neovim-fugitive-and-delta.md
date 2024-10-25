---
layout: post
title: 'Mastering Three-Way Merge with Neovim, Fugitive, and Delta'
date: 2024-10-24 00:00 +0000
tags: [vim, fugitive, delta, merge, three-way-merge, neovim]
---

# Mastering Three-Way Merge with Neovim, Fugitive, and Delta

## Table of Contents
1. [Introduction](#introduction)
2. [Installation](#installation)
3. [Configuration](#configuration)
4. [Understanding Three-Way Merge](#understanding-three-way-merge)
5. [Basic Operations](#basic-operations)
6. [Advanced Usage](#advanced-usage)
7. [Real-World Example](#real-world-example)
8. [Pro Tips and Tricks](#pro-tips-and-tricks)
9. [Troubleshooting](#troubleshooting)

## Introduction

Three-way merging is a common challenge in Git workflows. This guide will show you how to set up and use a powerful combination of tools - Neovim/Vim with Fugitive plugin and Delta - to handle merge conflicts efficiently. This setup provides a terminal-based, keyboard-driven workflow that can significantly speed up your merge resolution process.

## Installation

### Prerequisites
- Git (2.x or higher)
- Neovim (0.5.x or higher) or Vim (8.x or higher)
- A package manager (we'll use vim-plug in this guide)

### Step 1: Install Delta
```bash
# macOS
brew install git-delta

# Ubuntu/Debian
apt install git-delta

# Arch Linux
pacman -S git-delta
```

### Step 2: Install Fugitive
Add to your `init.vim` or `.vimrc`:
```vim
" Using vim-plug
call plug#begin()
Plug 'tpope/vim-fugitive'
call plug#end()
```

For Neovim with Lua:
```lua
-- Using Packer
use 'tpope/vim-fugitive'

-- Or using Lazy.nvim
{
    'tpope/vim-fugitive',
    cmd = { 'Git', 'G' }
}
```

Then install:
```vim
:PlugInstall
```

## Configuration

### Git Configuration
Add to your `~/.gitconfig`:
```ini
[merge]
    tool = nvimdiff
    conflictstyle = diff3

[mergetool "nvimdiff"]
    cmd = nvim -d $LOCAL $REMOTE $MERGED -c '$wincmd w' -c 'wincmd J'

[diff]
    tool = nvimdiff
    colorMoved = default

[core]
    pager = delta

[delta]
    navigate = true
    light = false
    side-by-side = true
    line-numbers = true
    syntax-theme = gruvbox-dark
    file-style = bold yellow ul
    file-decoration-style = none
    hunk-header-style = file line-number syntax
```

### Neovim Configuration
Add to your `init.vim` or `init.lua`:

```lua
-- Helpful keymaps for Git operations
vim.keymap.set('n', '<leader>gs', ':Git<CR>')
vim.keymap.set('n', '<leader>gd', ':Gdiffsplit<CR>')
vim.keymap.set('n', '<leader>gc', ':Git commit<CR>')
vim.keymap.set('n', '<leader>gb', ':Git blame<CR>')
vim.keymap.set('n', '<leader>gm', ':Git mergetool<CR>')

-- Improve diff experience
vim.opt.diffopt:append('algorithm:patience')
vim.opt.diffopt:append('indent-heuristic')
```

## Understanding Three-Way Merge

In a three-way merge, you're working with three versions of a file:
1. LOCAL (your current branch changes)
2. REMOTE (incoming changes from another branch)
3. BASE (common ancestor of both branches)

The merged result becomes the MERGED version.

## Basic Operations

### Starting a Merge
```bash
# Start your merge
git merge feature-branch

# If conflicts occur, launch the merge tool
git mergetool
```

### Window Layout
When you open the merge tool, you'll see this layout:
```
+----------------+------------------+
|     LOCAL      |      REMOTE     |
|  (your branch) | (their branch)  |
+----------------+------------------+
|             BASE                 |
|    (common ancestor)            |
+----------------+------------------+
|            MERGED               |
|     (final result)             |
+----------------+------------------+
```

### Essential Commands
```vim
" Navigation
]c          " Jump to next conflict
[c          " Jump to previous conflict

" Resolving conflicts
:diffget //2 " Get changes from LOCAL
:diffget //3 " Get changes from REMOTE
do          " Get changes from current window
dp          " Put changes to other window

" Utility
:diffupdate " Refresh diff highlighting
:wqa        " Save and exit all windows
```

## Advanced Usage

### Custom Functions
Add these to your Neovim config for enhanced functionality:

```lua
-- Quick conflict resolution
vim.keymap.set('n', '<leader>gj', ':diffget //3<CR>')  -- get from right
vim.keymap.set('n', '<leader>gf', ':diffget //2<CR>')  -- get from left

-- Show conflict stats
vim.cmd([[
function! ConflictStats()
    let l:conflict_pattern = '^<<<<<<< '
    let l:conflicts = search(l:conflict_pattern, 'n')
    echo "Remaining conflicts: " . l:conflicts
endfunction
]])
vim.keymap.set('n', '<leader>gc', ':call ConflictStats()<CR>')
```

## Real-World Example

Let's walk through resolving a merge conflict:

1. Create a conflict scenario:
```bash
# Create a test repository
git init test-merge
cd test-merge

# Create initial file
echo "Initial content" > file.txt
git add file.txt
git commit -m "Initial commit"

# Create and modify branch1
git checkout -b branch1
echo "Branch 1 changes" >> file.txt
git commit -am "Branch 1 changes"

# Create and modify branch2 from main
git checkout main
git checkout -b branch2
echo "Branch 2 changes" >> file.txt
git commit -am "Branch 2 changes"

# Try to merge
git checkout main
git merge branch1
git merge branch2  # This will create a conflict
```

2. Resolve the conflict:
```bash
# Open merge tool
git mergetool

# In Neovim:
# 1. Navigate to conflict with ]c
# 2. Review changes in each window
# 3. Choose changes:
#    - :diffget //2 for LOCAL changes
#    - :diffget //3 for REMOTE changes
# 4. Save with :w
# 5. Exit with :wqa

# Complete the merge
git add .
git commit -m "Merge branch2: resolve conflicts"
```

## Pro Tips and Tricks

1. Create shell aliases:
```bash
# Add to ~/.bashrc or ~/.zshrc
alias gmt='git mergetool'
alias gd='git difftool'
```

2. Use Fugitive's blame feature:
```vim
:Git blame  " Show blame information
```

3. Quick diff review:
```vim
:Gdiffsplit  " Open current file in diff view
```

4. Customize the merge view:
```vim
" Adjust diff colors
highlight DiffAdd    cterm=bold ctermfg=10 ctermbg=17 gui=none guifg=bg guibg=Red
highlight DiffDelete cterm=bold ctermfg=10 ctermbg=17 gui=none guifg=bg guibg=Red
highlight DiffChange cterm=bold ctermfg=10 ctermbg=17 gui=none guifg=bg guibg=Red
```

## Troubleshooting

### Common Issues and Solutions

1. **Delta not working**
   - Check if Delta is installed: `delta --version`
   - Verify Git config: `git config --get core.pager`

2. **Merge tool not opening**
   - Check Git merge tool setting: `git config --get merge.tool`
   - Verify Neovim installation: `nvim --version`

3. **Diff colors not showing**
   - Check terminal color support: `echo $TERM`
   - Try setting: `set termguicolors` in Neovim

### Best Practices

1. Always review the entire file before saving
2. Use `git status` to verify all conflicts are resolved
3. Write clear commit messages explaining merge decisions
4. Take advantage of Fugitive's `:Git log` to understand change history

Remember to complete your merge with:
```bash
git add .
git commit -m "Merge complete: [describe resolution strategy]"
```

This setup provides a powerful, efficient workflow for handling merge conflicts. With practice, you'll find that resolving conflicts becomes much faster and more intuitive using these tools together.
