---
layout: post
title: How to Extract the Second Page From Multiple PDFs and Combine Them on macOS
  2025-01-02
date: 2025-02-16 21:34 +0000
---
How to Extract the Second Page From Multiple PDFs and Combine Them on macOS
Managing PDFs on the command line may seem daunting at first, but it can be incredibly efficient for batch operations. Suppose you have dozens (or even hundreds) of PDF files and you want to do something very specific—like extracting the second page of every PDF and merging them into one consolidated file.

In this article, we’ll walk through an easy step-by-step process to accomplish exactly that. We’ll look at two approaches:

Using Poppler utilities (pdfseparate and pdfunite)
Using PDFlib’s pdftk
Both methods are widely used on Unix-like systems (including macOS). Let’s dive in!

Prerequisites
Homebrew: The easiest way to install command-line tools on macOS is through Homebrew. If you don’t have Homebrew installed, open your Terminal and run:

/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
Follow the onscreen instructions.

Poppler or pdftk: You’ll need at least one of these tools to perform the extraction and merge operations.

Approach 1: Using Poppler Utilities
Poppler is a widely used PDF rendering library that comes with several helpful command-line utilities, including:

pdfseparate: Splits a PDF file into individual pages or page ranges.
pdfunite: Merges PDF pages or entire PDF documents into one file.
Step 1: Install Poppler
With Homebrew, installation is straightforward:

brew install poppler
Step 2: Extract the Second Page of Each PDF
Assuming all your PDF files are in one folder, open the Terminal and navigate to that folder. For example:

cd /path/to/your/pdfs
Run the following for loop:

for f in *.pdf
do
    base="$(basename "$f" .pdf)"
    # Extract only page 2 and save it as base-page2.pdf
    pdfseparate -f 2 -l 2 "$f" "${base}-page2.pdf"
done
Here’s what each part means:

for f in *.pdf loops over every PDF file in the current directory.
basename "$f" .pdf extracts the filename without the .pdf extension.
pdfseparate -f 2 -l 2 instructs pdfseparate to start at page 2 and end at page 2, effectively extracting just the second page of the PDF.
"$f" "${base}-page2.pdf" tells the command to read from f (the current PDF file) and write out to a new file named after that PDF’s base name, plus -page2.pdf.
After this loop runs, you’ll have a set of new single-page PDF files ending with -page2.pdf.

Step 3: Combine All Extracted Pages
Next, we’ll merge these single-page PDFs into one consolidated file:

pdfunite *-page2.pdf combined-second-pages.pdf
The wildcard *-page2.pdf targets all the newly created second-page PDFs. The output, combined-second-pages.pdf, will contain the second page from each of your original PDFs, in alphabetical order by the original filename.

Step 4: Clean Up (Optional)
If you don’t need the individual -page2.pdf files anymore, you can delete them:

rm *-page2.pdf
At this point, you’ll have a clean folder with only the original PDFs and one merged PDF (combined-second-pages.pdf) containing all page 2s.

Approach 2: Using pdftk
pdftk (PDF Toolkit) is another popular command-line utility for PDF manipulation. Although it’s older, it still works well for tasks like splitting, merging, rotating, and watermarking PDF files.

Step 1: Install pdftk
Again, we’ll use Homebrew:

brew install pdftk
Step 2: Extract Page 2 From Each PDF
Similar to our Poppler approach, we’ll run a loop to extract only the second page from each PDF:

for f in *.pdf
do
    base="$(basename "$f" .pdf)"
    # Extract only page 2 and save it as base-page2.pdf
    pdftk "$f" cat 2 output "${base}-page2.pdf"
done
Step 3: Combine All Extracted Pages
To combine all those single-page files into one PDF, run:

pdftk ./*-page2.pdf cat output combined-second-pages.pdf
This creates combined-second-pages.pdf that sequentially contains all the second pages you extracted.

Step 4: (Optional) Clean Up
As before, you can remove the single-page PDFs if you don’t need them:

rm *-page2.pdf
Troubleshooting
No output files: Double-check your file extension. Make sure your PDFs are named .pdf (all lowercase) and that you’re in the correct directory.
Poppler or pdftk command not found: Verify that the tool you installed is properly linked to your PATH. This should happen automatically with Homebrew, but you may need to restart your Terminal for changes to take effect.
Permissions issues: If you’re working in a directory that requires elevated privileges, ensure that you have the right permissions or switch to a directory where you do.
Conclusion
Extracting specific pages from PDFs doesn’t have to be cumbersome. With utilities like Poppler’s pdfseparate and pdfunite or the versatile pdftk, you can quickly automate PDF tasks that might otherwise take hours of manual effort. These tools truly shine when you have large batches of files to process.

Key takeaways:

Poppler (pdfseparate, pdfunite) and pdftk are both great solutions for splitting and merging PDF files.
Using a simple for loop in the macOS Terminal can help you iterate over multiple PDFs in a folder.
You can fine-tune these commands to extract any page (or range of pages), not just page 2.
Now you have a single PDF, combined-second-pages.pdf, containing the second page from each of your PDF files. The entire process, from installing dependencies to cleaning up the workspace, can be done in just a few minutes. Give it a try and see how much time you save with your PDF tasks!
