# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a receipt processing workflow that automatically downloads emails from Gmail, converts them to PDF format, and extracts text content as Markdown. The workflow is designed for processing invoices, receipts, and other financial documents from email.

## Core Architecture

The workflow consists of a single bash script `process-receipts.sh` that orchestrates three Docker-based processing stages:

1. **Email Download**: Uses `perarneng/getgmail` to download emails with attachments from Gmail
2. **HTML to PDF Conversion**: Uses `perarneng/html2pdf` to convert email HTML bodies to PDF
3. **PDF Collection & Text Extraction**: Collects all PDFs into a single directory and converts them to Markdown using `markitdown`

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
The script uses three configurable Docker images defined at the top:
- `GETGMAIL_IMAGE="perarneng/getgmail:1.2.0"`
- `HTML2PDF_IMAGE="perarneng/html2pdf:1.1.0"`
- `MARKITDOWN_IMAGE="astral/uv:bookworm-slim"`

## Required Setup

### Credential Files
The script requires Google API credentials in the root directory:
- `credentials.json` - Google API credentials file
- `token.json` - OAuth token file

These files are automatically copied from `../getgmail/` if available and are excluded from git via `.gitignore`.

### Dependencies
- Docker (checked automatically at runtime)
- Google API credentials with Gmail access

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
└── markdown/                             # Consolidated markdown collection (configurable via MARKDOWN_FOLDER_NAME)
    └── *.md                              # Markdown text extractions
```

The folder names `mail`, `pdf`, and `markdown` can be customized by modifying the following variables at the top of the script:
- `MAIL_FOLDER_NAME="mail"`
- `PDF_FOLDER_NAME="pdf"`
- `MARKDOWN_FOLDER_NAME="markdown"`

## Error Handling

The script uses colored logging with timestamps and fails fast on errors. PDF to Markdown conversion uses extended timeout (`UV_HTTP_TIMEOUT=300`) to handle large dependency downloads.

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

### Performance Impact
- **First run**: Full processing (~31 seconds)
- **Subsequent runs**: ~5 seconds (83% time reduction)
- All stages efficiently skip existing content

## Development Notes

- The script is designed to be idempotent - running multiple times efficiently skips existing content
- All Docker operations use volume mounts for file access
- The `pdf2markdown` function uses `uvx --with markitdown[pdf]` to ensure PDF dependencies are available
- Logging functions (`_log_info`, `_log_warn`, `_log_err`) provide consistent colored output
- Duplicate prevention uses content comparison, not just filename matching
- File timestamp comparison ensures only outdated content gets regenerated