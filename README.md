# Receipt Processing Workflow

An automated pipeline for downloading emails from Gmail, converting them to PDF, and extracting text content as Markdown. Designed for processing invoices, receipts, and financial documents.

## Features

- 📧 **Email Download**: Automatically downloads emails with attachments from Gmail
- 📄 **PDF Conversion**: Converts email HTML content to PDF format
- 📝 **Text Extraction**: Converts all PDFs to Markdown for easy text processing
- 🎯 **Organized Output**: Structures files by timestamp and email subject
- 🚀 **Docker-based**: No local dependencies except Docker
- 🎨 **Colored Logging**: Clear progress tracking with timestamps

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

The workflow creates organized directories for each processed email:

```
output/
├── 2025-08-02_21-49-06_Your-receipt-from-Anthropic/
│   ├── *_body.html              # Original email HTML
│   ├── *_body.pdf               # Converted email PDF
│   ├── *_metadata.txt           # Email metadata
│   └── *_Receipt-123.pdf        # Email attachments
├── 2025-08-01_17-08-55_Google-Workspace-Invoice/
│   └── ...
└── all_pdfs/                    # Consolidated collection
    ├── *.pdf                    # All PDFs in one place
    └── *.md                     # Markdown extractions
```

## Workflow Stages

1. **📥 Email Download** - Downloads emails from Gmail INBOX with metadata and attachments
2. **🔄 HTML to PDF** - Converts email HTML bodies to PDF format
3. **📊 PDF Collection** - Copies all PDFs to a single directory
4. **📝 Text Extraction** - Converts PDFs to Markdown for text processing

## Configuration

Docker images can be updated by modifying variables at the top of `process-receipts.sh`:

```bash
GETGMAIL_IMAGE="perarneng/getgmail:1.1.0"
HTML2PDF_IMAGE="perarneng/html2pdf:1.0.0"
MARKITDOWN_IMAGE="astral/uv:bookworm-slim"
```

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