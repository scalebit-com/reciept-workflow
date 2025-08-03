# Receipt Processing Workflow

An automated pipeline for downloading emails from Gmail, converting them to PDF, extracting text content as Markdown, and generating professional overview reports using AI. Designed for processing invoices, receipts, and financial documents.

## Features

- 📧 **Email Download**: Automatically downloads emails with attachments from Gmail
- 📄 **PDF Conversion**: Converts email HTML content to PDF format
- 📝 **Text Extraction**: Converts all PDFs to Markdown for easy text processing
- 🤖 **AI Information Extraction**: Uses OpenAI to extract structured JSON data from receipts/invoices
- 📊 **Professional HTML Reports**: Generates A4-optimized HTML overview reports
- 🖨️ **Print-Ready PDFs**: Creates clean PDF reports for archiving and distribution
- 🎯 **Organized Output**: Configurable folder structure with 6 output directories
- ⚡ **Duplicate Prevention**: Intelligent detection prevents redundant processing
- 🚀 **Docker-based**: No local dependencies except Docker
- 🎨 **Colored Logging**: Clear progress tracking with timestamps
- 📈 **Performance**: Significant time reduction on subsequent runs

## Quick Start

### Prerequisites

1. **Docker** - Must be installed and running
2. **Google API Credentials** - Gmail API access required
3. **OpenAI API Key** - For AI-powered information extraction

### Setup

1. **Get Google API credentials:**
   - Enable Gmail API in Google Cloud Console
   - Download `credentials.json` file
   - Generate OAuth token as `token.json`

2. **Get OpenAI API key:**
   - Sign up for OpenAI API access
   - Generate an API key

3. **Place credential files:**
   ```bash
   # Copy credentials to project root
   cp path/to/credentials.json .
   cp path/to/token.json .
   
   # Create .env file with OpenAI credentials
   echo "OPENAI_KEY=your-openai-api-key-here" > .env
   echo "OPENAI_MODEL=gpt-4o-2024-08-06" >> .env
   ```

4. **Run the workflow:**
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
├── markdown/                    # Consolidated markdown collection (configurable)
│   └── *.md                     # Markdown text extractions
├── json/                        # AI-extracted structured data (configurable)
│   └── *.json                   # Receipt/invoice information in JSON format
├── html-overview/               # Professional HTML reports (configurable)
│   └── *.html                   # A4-optimized overview reports
└── pdf-overview/                # Print-ready PDF reports (configurable)
    └── *.pdf                    # Clean PDF reports for archiving
```

### Folder Customization

Folder names can be customized by modifying variables in `process-receipts.sh`:

```bash
MAIL_FOLDER_NAME="mail"                      # Email folders location
PDF_FOLDER_NAME="pdf"                        # Consolidated PDFs location  
MARKDOWN_FOLDER_NAME="markdown"              # Markdown files location
JSON_FOLDER_NAME="json"                      # AI-extracted JSON data location
HTML_OVERVIEW_FOLDER_NAME="html-overview"    # HTML reports location
PDF_OVERVIEW_FOLDER_NAME="pdf-overview"      # PDF reports location
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
5. **🤖 AI Information Extraction** - Extracts structured data from Markdown using OpenAI
   - ⚡ Skips extraction if JSON files are up-to-date
   - 📊 Generates structured JSON with company info, amounts, dates, and IDs
6. **📊 HTML Report Generation** - Creates professional A4-optimized HTML reports
   - ⚡ Timestamp-based duplicate prevention
   - 🎨 Professional formatting with financial details and document information
7. **🖨️ PDF Report Generation** - Converts HTML reports to print-ready PDF format
   - ⚡ Checks destination before generating to avoid unnecessary work
   - 📁 Moves final PDFs to dedicated overview folder

## Configuration

Docker images can be updated by modifying variables at the top of `process-receipts.sh`:

```bash
GETGMAIL_IMAGE="perarneng/getgmail:1.2.0"
HTML2PDF_IMAGE="perarneng/html2pdf:1.1.0"
MARKITDOWN_IMAGE="astral/uv:bookworm-slim"
RECEIPT_AI_IMAGE="perarneng/reciept-invoice-ai-tool:2.1.0"
```

### Environment Variables

Configure OpenAI integration in `.env` file:

```bash
OPENAI_KEY=your-openai-api-key-here
OPENAI_MODEL=gpt-4o-2024-08-06
```

## Efficiency & Duplicate Prevention

The workflow is designed for efficient re-execution:

### Performance
- **First run**: Full processing (includes AI processing time)
- **Subsequent runs**: Significant time reduction with comprehensive skipping
- **AI optimization**: JSON and HTML generation skipped when files are up-to-date
- **PDF optimization**: PDF generation avoided entirely when destination files exist

### Duplicate Detection
- **Email level**: Already downloaded emails are automatically skipped
- **PDF conversion**: Existing PDF files are not regenerated
- **File collection**: Content comparison prevents duplicate copies
- **Markdown conversion**: Only regenerates when source PDFs are newer
- **AI extraction**: JSON files skipped when newer than source markdown
- **Report generation**: HTML reports skipped when newer than source JSON
- **PDF reports**: Intelligent pre-check prevents unnecessary PDF generation

### No "_1" Files
Unlike simple filename-based systems, the workflow uses intelligent content comparison to prevent the creation of numbered duplicate files (e.g., `file_1.pdf`, `file_2.pdf`).

## Security

- Credential files (`credentials.json`, `token.json`) are automatically excluded from git
- Environment file (`.env`) with OpenAI API key is gitignored
- Output directory is gitignored to prevent accidental commits of sensitive data
- No credentials are stored in Docker images
- OpenAI API key is securely mounted as read-only volume to Docker containers

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

**"Failed to extract information"**
- Verify OpenAI API key is valid in .env file
- Check OpenAI API quota and billing status
- Ensure network connectivity for API calls

**"Failed to render HTML overview"**
- Check if JSON files exist and are valid
- Verify Docker image can access .env file
- Review OpenAI API connectivity

## Related Projects

This workflow integrates with:
- [getgmail](https://github.com/scalebit-com/getgmail) - Gmail email downloading tool
- [html2pdf](https://github.com/scalebit-com/html2pdf) - HTML to PDF conversion tool
- [reciept-invoice-ai-tool](https://github.com/scalebit-com/reciept-invoice-ai-tool) - AI-powered receipt/invoice information extraction

## Requirements

- Docker
- Gmail API credentials
- OpenAI API credentials
- Network access for downloading dependencies and API calls