#!/bin/bash

# Docker image configuration
GETGMAIL_IMAGE="perarneng/getgmail:1.2.0"
HTML2PDF_IMAGE="perarneng/html2pdf:1.1.0"
MARKITDOWN_IMAGE="astral/uv:bookworm-slim"

# Folder name configuration
MAIL_FOLDER_NAME="mail"
PDF_FOLDER_NAME="pdf"
MARKDOWN_FOLDER_NAME="markdown"

# ANSI color codes
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Global logging function
_log() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M')
    
    case "$level" in
        "ERROR")
            echo -e "${timestamp} ${RED}ERROR${NC} $message"
            ;;
        "WARN")
            echo -e "${timestamp} ${YELLOW}WARN${NC} $message"
            ;;
        "INFO")
            echo -e "${timestamp} ${GREEN}INFO${NC} $message"
            ;;
        *)
            echo -e "${timestamp} ${BLUE}${level}${NC} $message"
            ;;
    esac
}

# Convenience logging functions
_log_info() {
    _log "INFO" "$1"
}

_log_warn() {
    _log "WARN" "$1"
}

_log_err() {
    _log "ERROR" "$1"
}

# Check if Docker is available
check_docker() {
    _log_info "Checking Docker availability..."
    if ! command -v docker &> /dev/null; then
        _log_err "Docker is not installed or not in PATH"
        exit 1
    fi
    
    if ! docker info &> /dev/null; then
        _log_err "Docker daemon is not running or not accessible"
        exit 1
    fi
    
    _log_info "Docker is available and running"
}

# Check required files
check_required_files() {
    _log_info "Checking required credential files..."
    
    if [[ ! -f "credentials.json" ]]; then
        _log_err "credentials.json not found in current directory"
        exit 1
    fi
    
    if [[ ! -f "token.json" ]]; then
        _log_err "token.json not found in current directory"
        exit 1
    fi
    
    _log_info "All required files found"
}

# Show usage information
show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Options:
    -c, --count NUMBER     Number of emails to download (default: 10)
    -d, --dir DIRECTORY    Output directory (default: output)
    -h, --help            Show this help message

Examples:
    $0                    # Download 10 emails to output directory
    $0 -c 20              # Download 20 emails to output directory
    $0 -d my-emails -c 5  # Download 5 emails to my-emails directory
EOF
}

# Parse command line arguments
parse_args() {
    COUNT=10
    OUTPUT_DIR="output"
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -c|--count)
                COUNT="$2"
                if ! [[ "$COUNT" =~ ^[0-9]+$ ]]; then
                    _log_err "Count must be a positive number"
                    exit 1
                fi
                shift 2
                ;;
            -d|--dir)
                OUTPUT_DIR="$2"
                shift 2
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            *)
                _log_err "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
}

# Download emails using getgmail
download_emails() {
    local mail_dir="$OUTPUT_DIR/$MAIL_FOLDER_NAME"
    
    _log_info "Creating output directory: $mail_dir"
    mkdir -p "$mail_dir"
    
    _log_info "Downloading $COUNT emails to $mail_dir using $GETGMAIL_IMAGE"
    
    docker run --rm \
        -v "$(pwd):/app/data" \
        -e GOOGLE_CREDENTIALS_FILE=/app/data/credentials.json \
        -e GOOGLE_TOKEN_FILE=/app/data/token.json \
        "$GETGMAIL_IMAGE" download -d "/app/data/$mail_dir" -m INBOX -c "$COUNT"
    
    if [[ $? -eq 0 ]]; then
        _log_info "Email download completed successfully"
    else
        _log_err "Email download failed"
        exit 1
    fi
}

# Convert HTML files to PDF using html2pdf
convert_to_pdf() {
    local mail_dir="$OUTPUT_DIR/$MAIL_FOLDER_NAME"
    
    _log_info "Converting HTML files to PDF using $HTML2PDF_IMAGE"
    
    docker run --rm \
        -v "$(pwd)/$mail_dir:/app/data" \
        "$HTML2PDF_IMAGE" recurse -d . --skip-html-extension
    
    if [[ $? -eq 0 ]]; then
        _log_info "PDF conversion completed successfully"
    else
        _log_err "PDF conversion failed"
        exit 1
    fi
}

# Collect all PDF files into a single directory
collect_all_pdfs() {
    local all_pdfs_dir="$OUTPUT_DIR/$PDF_FOLDER_NAME"
    local mail_dir="$OUTPUT_DIR/$MAIL_FOLDER_NAME"
    
    _log_info "Collecting all PDF files into $all_pdfs_dir"
    
    # Create the all_pdfs directory if it doesn't exist
    mkdir -p "$all_pdfs_dir"
    
    # Find all PDF files recursively in the mail directory (excluding the pdf directory itself)
    local pdf_count=0
    while IFS= read -r -d '' pdf_file; do
        # Skip files that are already in the pdf directory
        if [[ "$pdf_file" == *"/$PDF_FOLDER_NAME/"* ]]; then
            continue
        fi
        
        # Get the basename of the PDF file
        local pdf_basename=$(basename "$pdf_file")
        local dest_file="$all_pdfs_dir/$pdf_basename"
        
        # Check if destination file already exists
        if [[ -f "$dest_file" ]]; then
            # Compare file sizes first (quick check)
            local src_size=$(stat -f%z "$pdf_file" 2>/dev/null || stat -c%s "$pdf_file" 2>/dev/null)
            local dest_size=$(stat -f%z "$dest_file" 2>/dev/null || stat -c%s "$dest_file" 2>/dev/null)
            
            if [[ "$src_size" == "$dest_size" ]]; then
                # If sizes match, do a full comparison
                if cmp -s "$pdf_file" "$dest_file"; then
                    _log_info "Skipped (identical file exists): $(basename "$pdf_file")"
                    continue
                fi
            fi
            
            # Files are different, need to find a new name
            local counter=1
            local original_basename="$pdf_basename"
            while [[ -f "$dest_file" ]]; do
                local name_without_ext="${original_basename%.pdf}"
                dest_file="$all_pdfs_dir/${name_without_ext}_${counter}.pdf"
                ((counter++))
            done
        fi
        
        # Copy the PDF file
        cp "$pdf_file" "$dest_file"
        if [[ $? -eq 0 ]]; then
            _log_info "Copied: $(basename "$pdf_file") -> $PDF_FOLDER_NAME/$(basename "$dest_file")"
            ((pdf_count++))
        else
            _log_warn "Failed to copy: $pdf_file"
        fi
    done < <(find "$mail_dir" -name "*.pdf" -type f -print0)
    
    if [[ $pdf_count -eq 0 ]]; then
        _log_warn "No PDF files found to collect"
    else
        _log_info "Successfully collected $pdf_count PDF files into $all_pdfs_dir"
    fi
}

# Convert PDF files to Markdown using markitdown
pdf2markdown() {
    local pdf_dir="$1"
    local md_dir="$OUTPUT_DIR/$MARKDOWN_FOLDER_NAME"
    
    _log_info "Converting PDF files to Markdown from $pdf_dir using $MARKITDOWN_IMAGE"
    _log_info "Output directory: $md_dir"
    
    # Check if the PDF directory exists
    if [[ ! -d "$pdf_dir" ]]; then
        _log_err "PDF directory does not exist: $pdf_dir"
        return 1
    fi
    
    # Create the markdown directory if it doesn't exist
    mkdir -p "$md_dir"
    
    # Find all PDF files in the directory
    local pdf_count=0
    local converted_count=0
    
    while IFS= read -r -d '' pdf_file; do
        ((pdf_count++))
        
        # Get the basename without extension
        local pdf_basename=$(basename "$pdf_file" .pdf)
        local md_file="$md_dir/${pdf_basename}.md"
        
        # Check if markdown file already exists
        if [[ -f "$md_file" ]] && [[ -s "$md_file" ]]; then
            # Get the PDF file modification time
            local pdf_mtime=$(stat -f%m "$pdf_file" 2>/dev/null || stat -c%Y "$pdf_file" 2>/dev/null)
            local md_mtime=$(stat -f%m "$md_file" 2>/dev/null || stat -c%Y "$md_file" 2>/dev/null)
            
            # If markdown file is newer than PDF, skip conversion
            if [[ "$md_mtime" -ge "$pdf_mtime" ]]; then
                _log_info "Skipped (up-to-date): $(basename "$pdf_file")"
                ((converted_count++))
                continue
            fi
        fi
        
        _log_info "Converting: $(basename "$pdf_file") -> $MARKDOWN_FOLDER_NAME/$(basename "$md_file")"
        
        # Run markitdown via Docker with PDF dependencies and capture both stdout and stderr
        local error_output
        error_output=$(docker run --rm \
            -v "$(pwd):/app/data" \
            -e UV_HTTP_TIMEOUT=300 \
            "$MARKITDOWN_IMAGE" \
            uvx --with markitdown[pdf] markitdown "/app/data/$pdf_file" 2>&1 > "$md_file")
        
        if [[ $? -eq 0 ]] && [[ -s "$md_file" ]]; then
            _log_info "Successfully converted: $(basename "$pdf_file")"
            ((converted_count++))
        else
            _log_err "Failed to convert: $(basename "$pdf_file")"
            if [[ -n "$error_output" ]]; then
                _log_err "Error details: $error_output"
            fi
            # Remove empty or failed markdown file
            rm -f "$md_file"
            exit 1
        fi
    done < <(find "$pdf_dir" -name "*.pdf" -type f -print0)
    
    if [[ $pdf_count -eq 0 ]]; then
        _log_warn "No PDF files found in $pdf_dir"
    else
        _log_info "PDF to Markdown conversion completed: $converted_count/$pdf_count files converted successfully"
        _log_info "Markdown files saved to: $md_dir"
    fi
}

# Main execution
main() {
    _log_info "Starting receipt processing workflow"
    
    parse_args "$@"
    check_docker
    check_required_files
    download_emails
    convert_to_pdf
    collect_all_pdfs
    pdf2markdown "$OUTPUT_DIR/$PDF_FOLDER_NAME"
    
    _log_info "Receipt processing workflow completed successfully"
    _log_info "Output directory: $OUTPUT_DIR"
}

# Run main function with all arguments
main "$@"