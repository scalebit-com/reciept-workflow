# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a receipt processing workflow that automatically downloads emails from Gmail, converts them to PDF format, and extracts text content as Markdown. The workflow is designed for processing invoices, receipts, and other financial documents from email.

## Core Architecture

The workflow consists of a single bash script `process-receipts.sh` that orchestrates six Docker-based processing stages:

1. **Email Download**: Uses `perarneng/getgmail` to download emails with attachments from Gmail
2. **HTML to PDF Conversion**: Uses `perarneng/html2pdf` to convert email HTML bodies to PDF
3. **PDF Collection & Text Extraction**: Collects all PDFs into a single directory and converts them to Markdown using `markitdown`
4. **JSON Information Extraction**: Uses `perarneng/reciept-invoice-ai-tool` to extract structured JSON data from Markdown files
5. **HTML Overview Generation**: Uses `perarneng/reciept-invoice-ai-tool` to generate professional HTML reports from JSON data
6. **PDF Overview Generation**: Converts HTML overview reports to PDF format and organizes them in a dedicated folder

## Key Commands

### Main Workflow
```bash
# Process 10 emails (default) to output/ directory
./process-receipts.sh

# Process specific number of emails
./process-receipts.sh -c 20

# Process emails to custom directory
./process-receipts.sh -d my-emails -c 5
```

### Docker Image Configuration
The script uses four configurable Docker images defined at the top:
- `GETGMAIL_IMAGE="perarneng/getgmail:1.2.0"`
- `HTML2PDF_IMAGE="perarneng/html2pdf:1.1.0"`
- `MARKITDOWN_IMAGE="astral/uv:bookworm-slim"`
- `RECEIPT_AI_IMAGE="perarneng/reciept-invoice-ai-tool:2.1.0"`

## Required Setup

### Credential Files
The script requires Google API credentials in the root directory:
- `credentials.json` - Google API credentials file
- `token.json` - OAuth token file

These files are automatically copied from `../getgmail/` if available and are excluded from git via `.gitignore`.

### Environment Configuration
The script requires OpenAI API credentials for JSON extraction:
- `.env` - Contains OpenAI API key and model configuration

Required environment variables:
- `OPENAI_KEY` - Your OpenAI API key
- `OPENAI_MODEL` - OpenAI model to use (e.g., gpt-4o-2024-08-06)

### Dependencies
- Docker (checked automatically at runtime)
- Google API credentials with Gmail access
- OpenAI API credentials for AI-powered JSON extraction

## Output Structure

```
output/
├── mail/                                 # All email folders (configurable via MAIL_FOLDER_NAME)
│   └── [timestamp]_[email-subject]/      # Individual email folders
│       ├── *_body.html                   # Email HTML content
│       ├── *_body.pdf                    # Converted PDF
│       ├── *_metadata.txt                # Email metadata
│       └── *_attachment.pdf              # Original attachments
├── pdf/                                  # Consolidated PDF collection (configurable via PDF_FOLDER_NAME)
│   └── *.pdf                             # All PDFs in one location
├── markdown/                             # Consolidated markdown collection (configurable via MARKDOWN_FOLDER_NAME)
│   └── *.md                              # Markdown text extractions
├── json/                                 # Structured JSON data (configurable via JSON_FOLDER_NAME)
│   └── *.json                            # AI-extracted receipt/invoice information
├── html-overview/                        # HTML overview reports (configurable via HTML_OVERVIEW_FOLDER_NAME)
│   └── *.html                            # Professional HTML reports for printing/viewing
└── pdf-overview/                         # Dedicated PDF overview collection (configurable via PDF_OVERVIEW_FOLDER_NAME)
    └── *.pdf                             # Clean PDF reports moved from html-overview/
```

The folder names can be customized by modifying the following variables at the top of the script:
- `MAIL_FOLDER_NAME="mail"`
- `PDF_FOLDER_NAME="pdf"`
- `MARKDOWN_FOLDER_NAME="markdown"`
- `JSON_FOLDER_NAME="json"`
- `HTML_OVERVIEW_FOLDER_NAME="html-overview"`
- `PDF_OVERVIEW_FOLDER_NAME="pdf-overview"`

## Error Handling

The script uses colored logging with timestamps and fails fast on errors. PDF to Markdown conversion uses extended timeout (`UV_HTTP_TIMEOUT=300`) to handle large dependency downloads. JSON extraction requires valid OpenAI API credentials and will fail if the AI service is unavailable.

## Efficiency & Duplicate Prevention

The script implements comprehensive duplicate prevention at every stage:

### Email Download (getgmail 1.2.0)
- Detects already downloaded emails and skips them
- Prevents duplicate attachment downloads
- Uses email ID comparison for detection

### PDF Conversion
- html2pdf automatically skips existing PDF files
- Compares output file existence before conversion
- No redundant PDF generation

### PDF Collection
- Compares file size and content before copying
- Skips identical files with "Skipped (identical file exists)" message
- Prevents creation of "_1" suffix files
- Only copies truly different files

### Markdown Conversion
- Uses timestamp comparison (PDF vs Markdown file modification time)
- Skips conversion if markdown is newer than source PDF
- Provides "Skipped (up-to-date)" feedback

### JSON Extraction
- Uses timestamp comparison (Markdown vs JSON file modification time)
- Skips extraction if JSON is newer than source markdown
- Provides "Skipped (up-to-date)" feedback
- Handles AI service errors gracefully

### HTML Overview Generation
- Uses timestamp comparison (JSON vs HTML file modification time)
- Skips rendering if HTML is newer than source JSON
- Provides "Skipped (up-to-date)" feedback
- Generates professional A4-optimized reports

### PDF Overview Generation
- Checks pdf-overview folder before generating PDFs to avoid unnecessary work
- Converts HTML overview reports to PDF format only if needed
- Moves PDF files to dedicated pdf-overview folder
- Skips PDF generation entirely if destination files already exist
- Provides informative logs for existing files and processing status

### Performance Impact
- **First run**: Full processing (includes AI extraction time)
- **Subsequent runs**: Significant time reduction due to comprehensive duplicate prevention
- All stages efficiently skip existing content

## Development Notes

- The script is designed to be idempotent - running multiple times efficiently skips existing content
- All Docker operations use volume mounts for file access
- The `pdf2markdown` function uses `uvx --with markitdown[pdf]` to ensure PDF dependencies are available
- The `extract_json_info` function uses the reciept-invoice-ai-tool Docker image with OpenAI API integration
- The `render_html_overview` function generates professional HTML reports optimized for A4 printing
- The `convert_to_pdf` function now accepts directory parameters for flexible HTML-to-PDF conversion
- The `move_pdf_overview_files` function efficiently organizes PDF reports in a dedicated folder
- Logging functions (`_log_info`, `_log_warn`, `_log_err`) provide consistent colored output
- Duplicate prevention uses content comparison, not just filename matching
- File timestamp comparison ensures only outdated content gets regenerated
- JSON extraction produces structured data including company info, amounts, dates, and suggested filenames
- HTML reports include document information, financial details, identification fields, and professional formatting
- PDF overview files provide print-ready documents for archiving and distribution