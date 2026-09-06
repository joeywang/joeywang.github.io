---
layout: post
title: "Zsh Command-Line Editing: Shortcuts Worth Learning"
date: 2025-03-17
tags: [zsh, linux, productivity, terminal]
categories: [Notes]
description: "A practical rundown of Zsh command-line editing: ZLE widgets, history reuse, globbing, and the handful of plugins that actually save keystrokes."
---

<audio controls preload="metadata" src="/assets/audio/make-bash-work-summary.ogg">
  Your browser does not support the audio element.
</audio>

Most people use a small fraction of what a shell's line editor can do: arrow keys, backspace, tab-complete a filename. The rest is what turns retyping a long command into a single keystroke. Zsh's line editor (ZLE) has more of that rest than most.

### Core editing, shared with Bash

These come from Readline and work in Emacs mode in both shells:

* **Cursor:** `Ctrl+A`/`Home` to line start, `Ctrl+E`/`End` to line end, `Alt+B`/`Alt+F` back and forward a word.
* **Cutting:** `Ctrl+U` cuts to line start, `Ctrl+K` cuts to line end, `Ctrl+W` cuts the word before the cursor, `Ctrl+Y` pastes it back.
* **History:** `Ctrl+P`/`Up` and `Ctrl+N`/`Down` step through history, `Ctrl+R` searches it interactively.

### Where Zsh goes further

**Tab completion** can show a navigable menu instead of just cycling:

```zsh
setopt auto_menu
setopt menu_complete
zstyle ':completion:*' menu select
```

It also corrects typos (`setopt correct`) and understands glob qualifiers inline, so `ls *(.x)` then `Tab` completes only executable files.

**ZLE widgets** are functions bound to key sequences. A few worth knowing:

* `push-line`: stashes the current line, lets you run something else, then restores it.
* `edit-command-line` (`Ctrl+X, Ctrl+E`, or `fc`): opens the current command in `$EDITOR` for anything too fiddly to edit inline.
* Custom widgets, if you want them:

```zsh
# In ~/.zshrc
sensible-pager() {
  BUFFER="$BUFFER | less"
  zle redisplay
}
zle -N sensible-pager
bindkey '^o^l' sensible-pager
```

Check `bindkey -L` before you claim a key combo: it's easy to clobber something already bound.

**Reusing arguments** instead of retyping them:

* `!*`: all arguments from the previous command.
* `!$`: the last argument of the previous command.
* `Alt+.`: insert the last argument; repeat to cycle through earlier ones.
* `^old^new^`: replace `old` with `new` in the last command and run it.

**Globbing** handles a lot of what people reach for `find` to do:

* `ls **/*.js`: recursive.
* `ls *(.)`, `*(/)`, `*(x)`: files only, directories only, executables only.
* `ls *(m-5)`: modified in the last 5 days. `ls *(Lk+100)`: larger than 100K.
* Combine qualifiers: `rm **/*(.tmpOLk+500)` removes large, old, regular temp files.

**`zmv`** batch-renames using the same glob syntax. Enable it with `autoload -U zmv`, then:

```zsh
zmv -n '(*).(jpeg|jpg)' 'image-${1}_${(L)2}.$2'
```

Drop `-n` once the dry run looks right.

### Frameworks and plugins

Oh My Zsh and Prezto package configuration and plugins so you don't hand-roll everything. Three plugins pull their weight on their own:

* `zsh-autosuggestions`: suggests a completion from history as you type; accept with the right arrow.
* `zsh-syntax-highlighting`: flags syntax errors before you hit enter.
* `history-substring-search`: cycles through history entries matching a substring you've already typed.

### Making it stick

Everything above lives in `~/.zshrc`: `setopt` for options, `bindkey` for key bindings, plugin config alongside. If a `bindkey` binding doesn't fire, press `Ctrl+V` then the key combo to see the literal escape sequence your terminal sends: that's what you bind to.

Pick two or three of these and use them until they're automatic before adding more. `Ctrl+R`, `!$`, and autosuggestions cover most of the daily friction; the rest is there for when you hit the specific problem it solves.
