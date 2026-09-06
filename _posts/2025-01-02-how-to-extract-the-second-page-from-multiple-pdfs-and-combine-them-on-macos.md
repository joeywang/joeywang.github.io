---
layout: post
title: Extracting the Second Page From Multiple PDFs on macOS
description: "How to batch-extract one page from many PDFs on macOS and merge the results into a single file, using Poppler's pdfseparate/pdfunite or pdftk."
date: 2025-01-02 21:34 +0000
categories: [Notes]
tags: [macos, cli, pdf, productivity]
---
<audio controls preload="metadata" src="/assets/audio/how-to-extract-the-second-page-from-multiple-pdfs-and-combine-them-on-macos-summary.ogg">
  Your browser does not support the audio element.
</audio>

If you have a folder of PDFs and need page 2 of each, pulled out and merged into one file, doing it by hand in Preview does not scale past a handful of documents. The command line does. Two toolchains handle it on macOS: Poppler's `pdfseparate`/`pdfunite`, and `pdftk`.

## Prerequisites

Install whichever tool you pick through Homebrew. If you do not have Homebrew:

```sh
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

## Approach 1: Poppler (`pdfseparate` and `pdfunite`)

```sh
brew install poppler
```

Extract page 2 from every PDF in the current folder:

```sh
for f in *.pdf
do
    base="$(basename "$f" .pdf)"
    # Extract only page 2 and save it as base-page2.pdf
    pdfseparate -f 2 -l 2 "$f" "${base}-page2.pdf"
done
```

`-f 2 -l 2` tells `pdfseparate` to start and end on page 2, so it pulls out exactly one page per file. Then merge the results in filename order:

```sh
pdfunite *-page2.pdf combined-second-pages.pdf
```

Clean up the intermediate files once you have `combined-second-pages.pdf`:

```sh
rm *-page2.pdf
```

## Approach 2: pdftk

`pdftk` (PDF Toolkit) is older but still handles splitting and merging well.

```sh
brew install pdftk
```

Same loop, different syntax:

```sh
for f in *.pdf
do
    base="$(basename "$f" .pdf)"
    # Extract only page 2 and save it as base-page2.pdf
    pdftk "$f" cat 2 output "${base}-page2.pdf"
done
```

```sh
pdftk ./*-page2.pdf cat output combined-second-pages.pdf
rm *-page2.pdf
```

## Troubleshooting

- **No output files**: check that your PDFs actually end in `.pdf` (lowercase) and that you are in the right directory.
- **Command not found**: Homebrew links binaries onto your `PATH` automatically, but a fresh Terminal session may need to be restarted to pick it up.
- **Permissions errors**: work in a directory you own rather than fighting for elevated privileges.

Either toolchain turns a tedious manual task into a few minutes of scripting, and the same loop works for any page or page range, not just page 2.
</content>
