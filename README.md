# Receipt Processing Workflow

An automated pipeline for downloading emails from Gmail, converting them to PDF, and extracting text content as Markdown. Designed for processing invoices, receipts, and financial documents.

## Features

- 📧 **Email Download**: Automatically downloads emails with attachments from Gmail
- 📄 **PDF Conversion**: Converts email HTML content to PDF format
- 📝 **Text Extraction**: Converts all PDFs to Markdown for easy text processing
- 🎯 **Organized Output**: Configurable folder structure (mail/pdf/markdown)
- ⚡ **Duplicate Prevention**: Intelligent detection prevents redundant processing
- 🚀 **Docker-based**: No local dependencies except Docker
- 🎨 **Colored Logging**: Clear progress tracking with timestamps
- 📈 **Performance**: 83% faster on subsequent runs

## Quick Start

### Prerequisites

1. **Docker** - Must be installed and running
2. **Google API Credentials** - Gmail API access required

### Setup

1. **Get Google API credentials:**
   - Enable Gmail API in Google Cloud Console
   - Download `credentials.json` file
   - Generate OAuth token as `token.json`

2. **Place credential files:**
   ```bash
   # Copy credentials to project root
   cp path/to/credentials.json .
   cp path/to/token.json .
   ```

3. **Run the workflow:**
   ```bash
   ./process-receipts.sh
   ```

## Usage

### Basic Commands

```bash
# Process 10 emails (default) to output/ directory
./process-receipts.sh

# Process specific number of emails
./process-receipts.sh -c 20

# Process emails to custom directory
./process-receipts.sh -d invoices -c 5

# Show help
./process-receipts.sh --help
```

### Command Options

- `-c, --count NUMBER` - Number of emails to download (default: 10)
- `-d, --dir DIRECTORY` - Output directory (default: output)
- `-h, --help` - Show help message

## Output Structure

The workflow creates organized directories with configurable folder names:

```
output/
├── mail/                        # All email folders (configurable)
│   ├── 2025-08-02_21-49-06_Your-receipt-from-Anthropic/
│   │   ├── *_body.html          # Original email HTML
│   │   ├── *_body.pdf           # Converted email PDF
│   │   ├── *_metadata.txt       # Email metadata
│   │   └── *_Receipt-123.pdf    # Email attachments
│   └── 2025-08-01_17-08-55_Google-Workspace-Invoice/
│       └── ...
├── pdf/                         # Consolidated PDF collection (configurable)
│   └── *.pdf                    # All PDFs in one place
└── markdown/                    # Consolidated markdown collection (configurable)
    └── *.md                     # Markdown text extractions
```

### Folder Customization

Folder names can be customized by modifying variables in `process-receipts.sh`:

```bash
MAIL_FOLDER_NAME="mail"          # Email folders location
PDF_FOLDER_NAME="pdf"            # Consolidated PDFs location  
MARKDOWN_FOLDER_NAME="markdown"  # Markdown files location
```

## Workflow Stages

1. **📥 Email Download** - Downloads emails from Gmail INBOX with metadata and attachments
   - ⚡ Skips already downloaded emails on subsequent runs
2. **🔄 HTML to PDF** - Converts email HTML bodies to PDF format
   - ⚡ Automatically skips existing PDF files
3. **📊 PDF Collection** - Copies all PDFs to a single directory
   - ⚡ Content comparison prevents duplicate files
4. **📝 Text Extraction** - Converts PDFs to Markdown for text processing
   - ⚡ Timestamp-based skipping for up-to-date files

## Configuration

Docker images can be updated by modifying variables at the top of `process-receipts.sh`:

```bash
GETGMAIL_IMAGE="perarneng/getgmail:1.2.0"
HTML2PDF_IMAGE="perarneng/html2pdf:1.1.0"
MARKITDOWN_IMAGE="astral/uv:bookworm-slim"
```

## Efficiency & Duplicate Prevention

The workflow is designed for efficient re-execution:

### Performance
- **First run**: Full processing (~30-60 seconds depending on email count)
- **Subsequent runs**: ~5 seconds with comprehensive skipping
- **Time savings**: Up to 83% reduction on re-runs

### Duplicate Detection
- **Email level**: Already downloaded emails are automatically skipped
- **PDF conversion**: Existing PDF files are not regenerated
- **File collection**: Content comparison prevents duplicate copies
- **Markdown conversion**: Only regenerates when source PDFs are newer

### No "_1" Files
Unlike simple filename-based systems, the workflow uses intelligent content comparison to prevent the creation of numbered duplicate files (e.g., `file_1.pdf`, `file_2.pdf`).

## Security

- Credential files (`credentials.json`, `token.json`) are automatically excluded from git
- Output directory is gitignored to prevent accidental commits of sensitive data
- No credentials are stored in Docker images

## Troubleshooting

### Common Issues

**"Docker is not running"**
- Start Docker Desktop or Docker daemon

**"credentials.json not found"**
- Ensure Google API credentials are in the project root
- Check file permissions

**"Failed to convert PDF"**
- Network timeout during dependency download
- Script automatically uses extended timeout (5 minutes)

**"No PDF files found to collect"**
- Normal message on subsequent runs when all files already exist
- Indicates efficient duplicate prevention is working

**"No emails found"**
- Check Gmail API permissions
- Verify token.json is valid and not expired

## Related Projects

This workflow integrates with:
- [getgmail](https://github.com/scalebit-com/getgmail) - Gmail email downloading tool
- [html2pdf](https://github.com/scalebit-com/html2pdf) - HTML to PDF conversion tool

## Requirements

- Docker
- Gmail API credentials
- Network access for downloading dependencies