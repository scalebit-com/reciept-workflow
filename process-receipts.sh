#!/bin/bash

# Docker image configuration
GETGMAIL_IMAGE="perarneng/getgmail:1.4.0"
HTML2PDF_IMAGE="perarneng/html2pdf:1.1.0"
MARKITDOWN_IMAGE="astral/uv:bookworm-slim"
RECEIPT_AI_IMAGE="perarneng/reciept-invoice-ai-tool:2.1.0"

# Folder name configuration
MAIL_FOLDER_NAME="mail"
PDF_FOLDER_NAME="pdf"
MARKDOWN_FOLDER_NAME="markdown"
JSON_FOLDER_NAME="json"
HTML_OVERVIEW_FOLDER_NAME="html-overview"
PDF_OVERVIEW_FOLDER_NAME="pdf-overview"
RECEIPTS_INVOICES_FOLDER_NAME="receipts_and_invoices"

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
    local target_dir="$1"
    local skip_if_exists_in_dest="$2"  # Optional parameter for destination directory to check
    
    if [[ -z "$target_dir" ]]; then
        _log_err "convert_to_pdf requires a target directory parameter"
        exit 1
    fi
    
    _log_info "Converting HTML files to PDF in $target_dir using $HTML2PDF_IMAGE"
    
    # Check if the target directory exists
    if [[ ! -d "$target_dir" ]]; then
        _log_err "Target directory does not exist: $target_dir"
        return 1
    fi
    
    # If skip_if_exists_in_dest is provided, check if PDFs already exist there
    if [[ -n "$skip_if_exists_in_dest" ]] && [[ -d "$skip_if_exists_in_dest" ]]; then
        _log_info "Checking for existing PDFs in $skip_if_exists_in_dest before generating"
        
        # Find HTML files and check if corresponding PDFs already exist in destination
        local html_files_to_process=0
        local html_files_skipped=0
        
        while IFS= read -r -d '' html_file; do
            local html_basename=$(basename "$html_file" .html)
            local dest_pdf="$skip_if_exists_in_dest/${html_basename}.pdf"
            
            if [[ -f "$dest_pdf" ]]; then
                _log_info "PDF already exists in destination, skipping HTML conversion: $(basename "$html_file")"
                ((html_files_skipped++))
            else
                ((html_files_to_process++))
            fi
        done < <(find "$target_dir" -name "*.html" -type f -print0)
        
        if [[ $html_files_to_process -eq 0 ]]; then
            _log_info "All HTML files already have corresponding PDFs in destination, skipping conversion"
            return 0
        fi
        
        _log_info "Processing $html_files_to_process HTML files ($html_files_skipped already exist in destination)"
    fi
    
    docker run --rm \
        -v "$(pwd)/$target_dir:/app/data" \
        "$HTML2PDF_IMAGE" recurse -d . --skip-html-extension
    
    if [[ $? -eq 0 ]]; then
        _log_info "PDF conversion completed successfully for $target_dir"
    else
        _log_err "PDF conversion failed for $target_dir"
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

# Extract JSON information from Markdown files using reciept-invoice-ai-tool
extract_json_info() {
    local md_dir="$OUTPUT_DIR/$MARKDOWN_FOLDER_NAME"
    local json_dir="$OUTPUT_DIR/$JSON_FOLDER_NAME"
    
    _log_info "Extracting JSON information from Markdown files in $md_dir using $RECEIPT_AI_IMAGE"
    _log_info "Output directory: $json_dir"
    
    # Check if the markdown directory exists
    if [[ ! -d "$md_dir" ]]; then
        _log_err "Markdown directory does not exist: $md_dir"
        return 1
    fi
    
    # Create the JSON directory if it doesn't exist
    mkdir -p "$json_dir"
    
    # Find all Markdown files in the directory
    local md_count=0
    local extracted_count=0
    
    while IFS= read -r -d '' md_file; do
        ((md_count++))
        
        # Get the basename without extension
        local md_basename=$(basename "$md_file" .md)
        local json_file="$json_dir/${md_basename}.json"
        
        # Check if JSON file already exists
        if [[ -f "$json_file" ]] && [[ -s "$json_file" ]]; then
            # Get the markdown file modification time
            local md_mtime=$(stat -f%m "$md_file" 2>/dev/null || stat -c%Y "$md_file" 2>/dev/null)
            local json_mtime=$(stat -f%m "$json_file" 2>/dev/null || stat -c%Y "$json_file" 2>/dev/null)
            
            # If JSON file is newer than markdown, skip extraction
            if [[ "$json_mtime" -ge "$md_mtime" ]]; then
                _log_info "Skipped (up-to-date): $(basename "$md_file")"
                ((extracted_count++))
                continue
            fi
        fi
        
        _log_info "Extracting: $(basename "$md_file") -> $JSON_FOLDER_NAME/$(basename "$json_file")"
        
        # Run reciept-invoice-ai-tool via Docker
        docker run --rm \
            -v "$(pwd):/app/data" \
            -v "$(pwd)/.env:/app/.env:ro" \
            "$RECEIPT_AI_IMAGE" \
            extract -i "/app/data/$md_file" -o "/app/data/$json_file"
        
        if [[ $? -eq 0 ]] && [[ -s "$json_file" ]]; then
            _log_info "Successfully extracted: $(basename "$md_file")"
            ((extracted_count++))
        else
            _log_err "Failed to extract: $(basename "$md_file")"
            # Remove empty or failed JSON file
            rm -f "$json_file"
            exit 1
        fi
    done < <(find "$md_dir" -name "*.md" -type f -print0)
    
    if [[ $md_count -eq 0 ]]; then
        _log_warn "No Markdown files found in $md_dir"
    else
        _log_info "JSON extraction completed: $extracted_count/$md_count files extracted successfully"
        _log_info "JSON files saved to: $json_dir"
    fi
}

# Generate HTML overview reports from JSON files using reciept-invoice-ai-tool
render_html_overview() {
    local json_dir="$OUTPUT_DIR/$JSON_FOLDER_NAME"
    local html_dir="$OUTPUT_DIR/$HTML_OVERVIEW_FOLDER_NAME"
    
    _log_info "Generating HTML overview reports from JSON files in $json_dir using $RECEIPT_AI_IMAGE"
    _log_info "Output directory: $html_dir"
    
    # Check if the JSON directory exists
    if [[ ! -d "$json_dir" ]]; then
        _log_err "JSON directory does not exist: $json_dir"
        return 1
    fi
    
    # Create the HTML overview directory if it doesn't exist
    mkdir -p "$html_dir"
    
    # Find all JSON files in the directory
    local json_count=0
    local rendered_count=0
    
    while IFS= read -r -d '' json_file; do
        ((json_count++))
        
        # Get the basename without extension
        local json_basename=$(basename "$json_file" .json)
        local html_file="$html_dir/${json_basename}.html"
        
        # Check if HTML file already exists
        if [[ -f "$html_file" ]] && [[ -s "$html_file" ]]; then
            # Get the JSON file modification time
            local json_mtime=$(stat -f%m "$json_file" 2>/dev/null || stat -c%Y "$json_file" 2>/dev/null)
            local html_mtime=$(stat -f%m "$html_file" 2>/dev/null || stat -c%Y "$html_file" 2>/dev/null)
            
            # If HTML file is newer than JSON, skip rendering
            if [[ "$html_mtime" -ge "$json_mtime" ]]; then
                _log_info "Skipped (up-to-date): $(basename "$json_file")"
                ((rendered_count++))
                continue
            fi
        fi
        
        _log_info "Rendering: $(basename "$json_file") -> $HTML_OVERVIEW_FOLDER_NAME/$(basename "$html_file")"
        
        # Run reciept-invoice-ai-tool htmloverview via Docker
        docker run --rm \
            -v "$(pwd):/app/data" \
            -v "$(pwd)/.env:/app/.env:ro" \
            "$RECEIPT_AI_IMAGE" \
            htmloverview -i "/app/data/$json_file" -o "/app/data/$html_file"
        
        if [[ $? -eq 0 ]] && [[ -s "$html_file" ]]; then
            _log_info "Successfully rendered: $(basename "$json_file")"
            ((rendered_count++))
        else
            _log_err "Failed to render: $(basename "$json_file")"
            # Remove empty or failed HTML file
            rm -f "$html_file"
            exit 1
        fi
    done < <(find "$json_dir" -name "*.json" -type f -print0)
    
    if [[ $json_count -eq 0 ]]; then
        _log_warn "No JSON files found in $json_dir"
    else
        _log_info "HTML overview generation completed: $rendered_count/$json_count files rendered successfully"
        _log_info "HTML files saved to: $html_dir"
    fi
}

# Move PDF overview files from html-overview to pdf-overview folder
move_pdf_overview_files() {
    local source_dir="$OUTPUT_DIR/$HTML_OVERVIEW_FOLDER_NAME"
    local dest_dir="$OUTPUT_DIR/$PDF_OVERVIEW_FOLDER_NAME"
    
    _log_info "Moving PDF overview files from $source_dir to $dest_dir"
    
    # Check if the source directory exists
    if [[ ! -d "$source_dir" ]]; then
        _log_err "Source directory does not exist: $source_dir"
        return 1
    fi
    
    # Create the destination directory if it doesn't exist
    mkdir -p "$dest_dir"
    
    # Find all PDF files in the source directory
    local pdf_count=0
    local moved_count=0
    
    while IFS= read -r -d '' pdf_file; do
        ((pdf_count++))
        
        # Get the basename of the PDF file
        local pdf_basename=$(basename "$pdf_file")
        local dest_file="$dest_dir/$pdf_basename"
        
        # Check if destination file already exists
        if [[ -f "$dest_file" ]]; then
            _log_warn "PDF overview file already exists in destination, removing source: $pdf_basename"
            rm -f "$pdf_file"
            continue
        fi
        
        # Move the PDF file
        mv "$pdf_file" "$dest_file"
        if [[ $? -eq 0 ]]; then
            _log_info "Moved PDF overview: $pdf_basename -> $PDF_OVERVIEW_FOLDER_NAME/"
            ((moved_count++))
        else
            _log_err "Failed to move PDF overview: $pdf_file"
            exit 1
        fi
    done < <(find "$source_dir" -name "*.pdf" -type f -print0)
    
    if [[ $pdf_count -eq 0 ]]; then
        _log_warn "No PDF files found in $source_dir"
    else
        _log_info "PDF overview move completed: $moved_count/$pdf_count files moved successfully"
        _log_info "PDF overview files saved to: $dest_dir"
    fi
}

# Consolidate receipts and invoices by combining overview and original PDFs
consolidate_pdf_receipts() {
    local json_dir="$OUTPUT_DIR/$JSON_FOLDER_NAME"
    local pdf_dir="$OUTPUT_DIR/$PDF_FOLDER_NAME"
    local overview_dir="$OUTPUT_DIR/$PDF_OVERVIEW_FOLDER_NAME"
    local receipts_dir="$OUTPUT_DIR/$RECEIPTS_INVOICES_FOLDER_NAME"
    
    _log_info "Consolidating PDF receipts and invoices from $json_dir"
    _log_info "Output directory: $receipts_dir"
    
    # Check if required directories exist
    if [[ ! -d "$json_dir" ]]; then
        _log_err "JSON directory does not exist: $json_dir"
        return 1
    fi
    
    if [[ ! -d "$pdf_dir" ]]; then
        _log_err "PDF directory does not exist: $pdf_dir"
        return 1
    fi
    
    if [[ ! -d "$overview_dir" ]]; then
        _log_err "PDF overview directory does not exist: $overview_dir"
        return 1
    fi
    
    # Create the receipts and invoices directory if it doesn't exist
    mkdir -p "$receipts_dir"
    
    # Check if yq command is available
    if ! command -v yq &> /dev/null; then
        _log_err "yq command is not available. Please install yq to use this function."
        return 1
    fi
    
    # Check if pdfunite command is available
    if ! command -v pdfunite &> /dev/null; then
        _log_err "pdfunite command is not available. Please install poppler-utils to use this function."
        return 1
    fi
    
    # Find all JSON files in the directory
    local json_count=0
    local processed_count=0
    local skipped_count=0
    
    while IFS= read -r -d '' json_file; do
        ((json_count++))
        
        # Get the basename without extension
        local json_basename=$(basename "$json_file" .json)
        
        # Check if document_type is not "None"
        local document_type=$(yq -r '.document_type' "$json_file" 2>/dev/null)
        
        if [[ -z "$document_type" ]] || [[ "$document_type" == "null" ]] || [[ "$document_type" == "None" ]]; then
            _log_info "Skipped (not a receipt/invoice): $(basename "$json_file") - document_type: $document_type"
            ((skipped_count++))
            continue
        fi
        
        # Extract suggested filename
        local suggested_filename=$(yq -r '.suggested_filename' "$json_file" 2>/dev/null)
        
        if [[ -z "$suggested_filename" ]] || [[ "$suggested_filename" == "null" ]]; then
            _log_warn "Skipped (no suggested filename): $(basename "$json_file")"
            ((skipped_count++))
            continue
        fi
        
        # Create target filename with .pdf extension
        local target_file="$receipts_dir/${suggested_filename}.pdf"
        
        # Check if target file already exists
        if [[ -f "$target_file" ]]; then
            _log_warn "Target file already exists, skipping: $(basename "$target_file")"
            ((skipped_count++))
            continue
        fi
        
        # Find corresponding PDF files
        local overview_pdf="$overview_dir/${json_basename}.pdf"
        local original_pdf="$pdf_dir/${json_basename}.pdf"
        
        # Check if both PDF files exist
        if [[ ! -f "$overview_pdf" ]]; then
            _log_warn "Overview PDF not found, skipping: $overview_pdf"
            ((skipped_count++))
            continue
        fi
        
        if [[ ! -f "$original_pdf" ]]; then
            _log_warn "Original PDF not found, skipping: $original_pdf"
            ((skipped_count++))
            continue
        fi
        
        _log_info "Consolidating: $(basename "$json_file") -> $RECEIPTS_INVOICES_FOLDER_NAME/$(basename "$target_file")"
        
        # Combine PDFs with overview first (as cover page), then original
        pdfunite "$overview_pdf" "$original_pdf" "$target_file"
        
        if [[ $? -eq 0 ]] && [[ -f "$target_file" ]]; then
            _log_info "Successfully consolidated: $(basename "$target_file")"
            ((processed_count++))
        else
            _log_err "Failed to consolidate: $(basename "$json_file")"
            # Remove failed target file if it exists
            rm -f "$target_file"
            exit 1
        fi
    done < <(find "$json_dir" -name "*.json" -type f -print0)
    
    if [[ $json_count -eq 0 ]]; then
        _log_warn "No JSON files found in $json_dir"
    else
        _log_info "PDF consolidation completed: $processed_count processed, $skipped_count skipped out of $json_count total files"
        _log_info "Consolidated files saved to: $receipts_dir"
    fi
}

# Main execution
main() {
    _log_info "Starting receipt processing workflow"
    
    parse_args "$@"
    check_docker
    check_required_files
    download_emails
    convert_to_pdf "$OUTPUT_DIR/$MAIL_FOLDER_NAME"
    collect_all_pdfs
    pdf2markdown "$OUTPUT_DIR/$PDF_FOLDER_NAME"
    extract_json_info
    render_html_overview
    convert_to_pdf "$OUTPUT_DIR/$HTML_OVERVIEW_FOLDER_NAME" "$OUTPUT_DIR/$PDF_OVERVIEW_FOLDER_NAME"
    move_pdf_overview_files
    consolidate_pdf_receipts
    
    _log_info "Receipt processing workflow completed successfully"
    _log_info "Output directory: $OUTPUT_DIR"
}

# Run main function with all arguments
main "$@"