---
layout: post
title: Font Support with Prawn and test 2025-01-03
date: 2025-01-03 14:58 +0000
---
# Debugging Font Support Issues with Prawn and PDF::Inspector in Ruby

When working with PDF generation in Ruby using Prawn and testing with PDF::Inspector, developers often encounter challenges with non-ASCII character support, particularly when dealing with Unicode characters like Cyrillic, Chinese, or Arabic. This article explores common issues, debugging techniques, and practical solutions for handling font support in PDF generation and testing.

## The Challenge with Non-ASCII Characters

Prawn and PDF::Inspector handle text differently, which can lead to discrepancies between what appears in the generated PDF and what can be extracted for testing. A common scenario is when generating PDFs with Unicode characters:

```ruby
pdf = Prawn::Document.new
pdf.text "наприклад, Петро" # Ukrainian text

# Test that might fail
text_analysis = PDF::Inspector::Text.analyze(pdf.render)
expect(text_analysis.strings.first).to eq("наприклад, Петро") # May fail
```

## Common Issues

1. **Font Embedding Problems**
- Missing font files
- Incomplete character sets in selected fonts
- Improper font family registration

2. **Encoding Mismatches**
- UTF-8 vs other encodings
- Binary string handling
- Character set conversion issues

3. **PDF::Inspector Limitations**
- Incomplete Unicode support
- Font subset extraction challenges
- Complex text layout interpretation

## Debugging Techniques

### 1. Verify PDF Generation

First, confirm that the PDF is generated correctly:

```ruby
def debug_pdf_content(pdf)
# Save PDF to file for manual inspection
pdf.render_file("debug_output.pdf")

# Examine raw PDF content
raw_content = pdf.render
puts "Raw PDF size: #{raw_content.bytesize}"
puts "Content encoding: #{raw_content.encoding}"
end
```

### 2. Inspect Font Configuration

Check font registration and embedding:

```ruby
pdf = Prawn::Document.new

# Debug font configuration
puts "Available fonts: #{pdf.font_families.keys}"
puts "Current font: #{pdf.font.name}"
puts "Font reference: #{pdf.font.identifier}"
```

### 3. Text Extraction Analysis

Compare different text extraction methods:

```ruby
pdf_content = pdf.render

# Method 1: PDF::Inspector
inspector_text = PDF::Inspector::Text.analyze(pdf_content).strings

# Method 2: PDF::Reader
reader_text = PDF::Reader.new(StringIO.new(pdf_content)).pages.first.text

# Method 3: HexaPDF
hexapdf_text = HexaPDF::Document.new(io: StringIO.new(pdf_content))
                            .pages.first.text

puts "Inspector: #{inspector_text}"
puts "Reader: #{reader_text}"
puts "HexaPDF: #{hexapdf_text}"
```

## Solutions and Best Practices

### 1. Proper Font Configuration

```ruby
pdf.font_families.update(
"DejaVu Sans" => {
    normal: "#{Rails.root}/app/assets/fonts/DejaVuSans.ttf",
    bold: "#{Rails.root}/app/assets/fonts/DejaVuSans-Bold.ttf",
    italic: "#{Rails.root}/app/assets/fonts/DejaVuSans-Oblique.ttf"
}
)

pdf.font "DejaVu Sans"
```

### 2. Alternative Testing Approaches

When PDF::Inspector fails to read certain characters correctly:

```ruby
RSpec.describe "PDF Generation" do
it "contains correct text" do
    pdf_content = pdf.render

    # Approach 1: Use PDF::Reader
    reader = PDF::Reader.new(StringIO.new(pdf_content))
    expect(reader.pages.first.text).to include("наприклад")

    # Approach 2: Check raw content
    expect(pdf_content.force_encoding('UTF-8')).to include("наприклад")

    # Approach 3: Use simpler text patterns
    expect(reader.pages.first.text).to include("от") # Instead of "наприклад"
end
end
```

### 3. Fallback Mechanisms

Implement fallback strategies for different character sets:

```ruby
def safe_text_rendering(text, pdf)
begin
    pdf.text text
rescue Prawn::Errors::IncompatibleStringEncoding
    fallback_text = text.encode('UTF-8', invalid: :replace,
                            undef: :replace, replace: '?')
    pdf.text fallback_text
end
end
```

## Conclusion

Font support issues in PDF generation and testing require a multi-faceted approach. Key takeaways:

1. Always verify PDF output manually before automated testing
2. Use appropriate fonts with complete character support
3. Consider alternative testing strategies when PDF::Inspector falls short
4. Implement proper error handling and fallback mechanisms
5. Choose simpler text patterns for testing when possible

## Resources

- [Prawn Documentation](https://prawnpdf.org/docs)
- [PDF::Inspector GitHub](https://github.com/prawnpdf/pdf-inspector)
- [PDF::Reader Documentation](https://github.com/yob/pdf-reader)
- [HexaPDF Documentation](https://hexapdf.gettalong.org/)


