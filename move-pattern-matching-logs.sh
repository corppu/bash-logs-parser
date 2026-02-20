#!/bin/bash

##############################################################################
# Pattern Matching Script - Extract Complete Log Entries
# 
# Searches for patterns in log files and extracts complete log entries
# (from timestamp to timestamp). Preserves directory structure in output.
#
# Usage:
#   ./move-pattern-matching-logs.sh -p PATTERN -i INPUT_DIR [-o OUTPUT_DIR] [-t TIMESTAMP_REGEX]
#   ./move-pattern-matching-logs.sh -p "ERROR" -i ./logs -o ./results
#
##############################################################################

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
PATTERN=""
INPUT_DIR=""
OUTPUT_DIR=""
TIMESTAMP_REGEX='^\[?[0-9]{4}-[0-9]{2}-[0-9]{2}'  # Default: YYYY-MM-DD (with optional [)
ARCHIVE_EXT_REGEX='\.(zip|gz|tar|tgz|tar\.gz)$'
MATCH_COUNT=0
ENTRY_COUNT=0
SKIPPED_COUNT=0
VERBOSE=false
PROCESSED_FILES=0
TOTAL_FILES=0
TOTAL_ZIP_FILES=0
TOTAL_GZ_FILES=0
TOTAL_TAR_FILES=0
PROCESSED_LINES=0
TOTAL_LINES=0
START_TIME=0

##############################################################################
# Format seconds to human-readable duration
##############################################################################
format_duration() {
    local seconds=$1
    local hours=$((seconds / 3600))
    local minutes=$(((seconds % 3600) / 60))
    local secs=$((seconds % 60))
    
    if [[ $hours -gt 0 ]]; then
        printf "%dh %dm %ds" $hours $minutes $secs
    elif [[ $minutes -gt 0 ]]; then
        printf "%dm %ds" $minutes $secs
    else
        printf "%ds" $secs
    fi
}

##############################################################################
# Print usage information
##############################################################################
print_usage() {
    cat << EOF
Usage: $(basename "$0") -p PATTERN [-p PATTERN2] ... -i INPUT_DIR [-o OUTPUT_DIR] [-t TIMESTAMP_REGEX] [-v]

Required Arguments:
  -p PATTERN           Pattern to search for (supports regex, can be used multiple times)
  -i INPUT_DIR         Input directory to search in

Optional Arguments:
  -o OUTPUT_DIR        Output directory for results (recreates structure)
                       Default: INPUT_DIR/matched
  -t TIMESTAMP_REGEX   Regex to identify log entry start (default: ^\[?[0-9]{4}-[0-9]{2}-[0-9]{2})
  -v                   Verbose output (shows skipped files)
  -h                   Display this help message

Examples:
  $(basename "$0") -p "ERROR" -i ./logs
  $(basename "$0") -p "ERROR" -p "WARN" -i ./logs -o ./results
  $(basename "$0") -p "ERROR" -p "Exception" -p "FAIL" -i ./logs
  $(basename "$0") -p "ERROR|WARN" -i ./logs -o ./results
  $(basename "$0") -p "Exception" -i /var/log -o /tmp/matches -t '^\[[0-9]{4}-'

EOF
}

##############################################################################
# Parse command line arguments
##############################################################################
parse_args() {
    while getopts ":p:i:o:t:vh" opt; do
        case $opt in
            p)
                # Accumulate multiple patterns with | separator
                if [[ -z "$PATTERN" ]]; then
                    PATTERN="$OPTARG"
                else
                    PATTERN="${PATTERN}|${OPTARG}"
                fi
                ;;
            i)
                INPUT_DIR="$OPTARG"
                ;;
            o)
                OUTPUT_DIR="$OPTARG"
                ;;
            t)
                TIMESTAMP_REGEX="$OPTARG"
                ;;
            v)
                VERBOSE=true
                ;;
            h)
                print_usage
                exit 0
                ;;
            \?)
                echo -e "${RED}Invalid option: -$OPTARG${NC}" >&2
                print_usage
                exit 1
                ;;
            :)
                echo -e "${RED}Option -$OPTARG requires an argument.${NC}" >&2
                print_usage
                exit 1
                ;;
        esac
    done
}

##############################################################################
# Validate inputs
##############################################################################
validate_inputs() {
    if [[ -z "$PATTERN" ]]; then
        echo -e "${RED}Error: Pattern is required (-p)${NC}" >&2
        print_usage
        exit 1
    fi

    if [[ -z "$INPUT_DIR" ]]; then
        echo -e "${RED}Error: Input directory is required (-i)${NC}" >&2
        print_usage
        exit 1
    fi

    if [[ ! -d "$INPUT_DIR" ]]; then
        echo -e "${RED}Error: Input directory does not exist: $INPUT_DIR${NC}" >&2
        exit 1
    fi

    # Set default output directory if not provided
    if [[ -z "$OUTPUT_DIR" ]]; then
        OUTPUT_DIR="${INPUT_DIR}/matched"
    fi

    mkdir -p "$OUTPUT_DIR"
}

##############################################################################
# Check if regular file contains pattern (using grep)
##############################################################################
file_has_pattern() {
    local file="$1"

    if ! grep -qE "$PATTERN" "$file" 2>/dev/null; then
        if [[ "$VERBOSE" == true ]]; then
            echo -e "${YELLOW}⊘ Skipped (no pattern match): $file${NC}"
        fi
        return 1
    fi

    return 0
}

##############################################################################
# Check if zip file contains pattern (using zipgrep) or nested archives
##############################################################################
zip_file_has_pattern() {
    local zip_file="$1"
    
    # zipgrep doesn't support alternation (|) in patterns, so split and test each part
    # Convert pattern like "pat1|pat2|pat3" into array
    IFS='|' read -ra pattern_parts <<< "$PATTERN"
    
    # Test each pattern part separately
    for part in "${pattern_parts[@]}"; do
        if zipgrep -qE "$part" "$zip_file" 2>/dev/null; then
            return 0
        fi
    done
    
    # Check if zip contains nested archives by name
    if zipinfo -1 "$zip_file" 2>/dev/null | grep -qiE "$ARCHIVE_EXT_REGEX"; then
        return 0
    fi

    if [[ "$VERBOSE" == true ]]; then
        echo -e "${YELLOW}⊘ Skipped (no pattern match in zip): $zip_file${NC}"
    fi
    
    return 1
}

##############################################################################
# Check if gzip file contains pattern or nested archives
##############################################################################
gz_file_has_pattern() {
    local gz_file="$1"
    
    # zgrep might not support alternation (|) in patterns, so split and test each part
    # Convert pattern like "pat1|pat2|pat3" into array
    IFS='|' read -ra pattern_parts <<< "$PATTERN"
    
    # Test each pattern part separately
    for part in "${pattern_parts[@]}"; do
        if zgrep -qE "$part" "$gz_file" 2>/dev/null; then
            return 0
        fi
    done
    
    # Check if gzip likely contains an archive by original name
    if gunzip -l "$gz_file" 2>/dev/null | awk 'NR>1 {print $NF}' | grep -qiE "$ARCHIVE_EXT_REGEX"; then
        return 0
    fi

    if [[ "$VERBOSE" == true ]]; then
        echo -e "${YELLOW}⊘ Skipped (no pattern match in gz): $gz_file${NC}"
    fi
    
    return 1
}

##############################################################################
# Get file MIME type
##############################################################################
get_mime_type() {
    local file="$1"
    file -b --mime-type -- "$file" 2>/dev/null
}

##############################################################################
# Check if file is an archive MIME type
##############################################################################
is_archive_mime() {
    local mime_type=$(get_mime_type "$1")

    case "$mime_type" in
        application/zip|application/gzip|application/x-tar)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

##############################################################################
# Check if a gzip file is actually a tar.gz archive
##############################################################################
is_tar_gz_archive() {
    local gz_file="$1"
    tar -tzf "$gz_file" >/dev/null 2>&1
}

##############################################################################
# Check if tar file contains pattern
##############################################################################
tar_file_has_pattern() {
    local tar_file="$1"

    if ! tar -xOf "$tar_file" 2>/dev/null | grep -qE "$PATTERN"; then
        if [[ "$VERBOSE" == true ]]; then
            echo -e "${YELLOW}⊘ Skipped (no pattern match in tar): $tar_file${NC}"
        fi
        return 1
    fi

    return 0
}

##############################################################################
# Check if tar.gz or tgz file contains pattern
##############################################################################
tar_gz_file_has_pattern() {
    local tar_file="$1"

    if ! tar -xOzf "$tar_file" 2>/dev/null | grep -qE "$PATTERN"; then
        if [[ "$VERBOSE" == true ]]; then
            echo -e "${YELLOW}⊘ Skipped (no pattern match in tar.gz): $tar_file${NC}"
        fi
        return 1
    fi

    return 0
}

##############################################################################
# Extract and filter complete log entries
##############################################################################
extract_and_filter_entries() {
    local input_file="$1"
    local output_file="$2"
    
    # Use grep to find line numbers matching the pattern (FAST!)
    local pattern_lines=$(grep -nE "$PATTERN" "$input_file" 2>/dev/null | cut -d: -f1)
    
    if [[ -z "$pattern_lines" ]]; then
        # No matches found in this file
        return
    fi
    
    # Use grep to find line numbers starting with timestamp (entry boundaries)
    local timestamp_lines=$(grep -nE "$TIMESTAMP_REGEX" "$input_file" 2>/dev/null | cut -d: -f1)
    
    if [[ -z "$timestamp_lines" ]]; then
        # No timestamp entries found, process entire file if pattern matches
        cat "$input_file" > "$output_file"
        ((ENTRY_COUNT++))
        return
    fi
    
    # Create array of unique entry starting line numbers to extract
    declare -A entries_to_extract
    
    # For each line matching the pattern, find the entry (timestamp) it belongs to
    while IFS= read -r pattern_line; do
        # Find the timestamp line at or before this pattern line
        local entry_start=""
        local prev_ts_line=0
        
        while IFS= read -r ts_line; do
            if [[ $ts_line -le $pattern_line ]]; then
                entry_start=$ts_line
                prev_ts_line=$ts_line
            else
                break
            fi
        done <<< "$timestamp_lines"
        
        # Mark this entry to be extracted
        if [[ -n "$entry_start" ]]; then
            entries_to_extract[$entry_start]=1
        fi
    done <<< "$pattern_lines"
    
    # Get total line count for calculating entry end boundaries
    # Use grep -c to count actual lines (handles files without trailing newline)
    local total_lines=$(grep -c '' "$input_file" 2>/dev/null)
    
    # Convert timestamp_lines to array for binary search
    local -a ts_array
    while IFS= read -r line; do
        ts_array+=("$line")
    done <<< "$timestamp_lines"
    
    # Extract and write complete entries
    local first_write=true
    for entry_start in $(printf '%s\n' "${!entries_to_extract[@]}" | sort -n); do
        # Find the next timestamp line to determine entry end
        local entry_end=$total_lines
        local found_next=false
        
        for ts_line in "${ts_array[@]}"; do
            if [[ $ts_line -gt $entry_start ]]; then
                entry_end=$((ts_line - 1))
                found_next=true
                break
            fi
        done
        
        # Extract lines from entry_start to entry_end using sed
        # Use > for first write, >> for subsequent writes
        if [[ "$first_write" == true ]]; then
            sed -n "${entry_start},${entry_end}p" "$input_file" > "$output_file"
            first_write=false
        else
            sed -n "${entry_start},${entry_end}p" "$input_file" >> "$output_file"
        fi
        
        if [[ "$VERBOSE" == true ]]; then
            echo -e "${BLUE}  ↳ Lines ${entry_start}-${entry_end} from: $input_file${NC}"
        fi
        ((ENTRY_COUNT++))
    done
}

##############################################################################
# Process unzipped log files
##############################################################################
process_unzipped() {
    local input_file="$1"
    local rel_path="$2"
    
    # Filter files: skip if pattern not found (optimization for huge directories)
    if ! file_has_pattern "$input_file"; then
        ((SKIPPED_COUNT++))
        return
    fi
    
    local output_file="$OUTPUT_DIR/$rel_path"
    
    # Create output directory structure
    mkdir -p "$(dirname "$output_file")"
    
    # Calculate and show progress percentages
    local file_percent=0
    if [[ $TOTAL_FILES -gt 0 ]]; then
        file_percent=$((PROCESSED_FILES * 100 / TOTAL_FILES))
    fi
    local files_remaining=$((TOTAL_FILES - PROCESSED_FILES))
    
    # Calculate time and ETA
    local current_time=$(date +%s)
    local elapsed=$((current_time - START_TIME))
    local eta_str="calculating..."
    local speed_str=""
    
    if [[ $elapsed -gt 0 && $PROCESSED_FILES -gt 0 ]]; then
        # Calculate files per second
        local files_per_sec_x100=$((PROCESSED_FILES * 100 / elapsed))
        
        if [[ $files_per_sec_x100 -gt 0 ]]; then
            # Estimate remaining time based on files
            local eta_seconds=$((files_remaining * elapsed / PROCESSED_FILES))
            eta_str=$(format_duration $eta_seconds)
            
            # Format speed
            if [[ $files_per_sec_x100 -ge 100 ]]; then
                local fps=$((files_per_sec_x100 / 100))
                speed_str="${fps} files/s"
            else
                local spf=$((elapsed / PROCESSED_FILES))
                speed_str="${spf}s/file"
            fi
        fi
    fi
    
    echo -e "${BLUE}Processing [$PROCESSED_FILES/$TOTAL_FILES - ${file_percent}%] ($files_remaining left) [ETA: $eta_str, Speed: $speed_str]: $rel_path${NC}"
    
    # Extract and filter entries
    extract_and_filter_entries "$input_file" "$output_file"
    
    # Check if output file was created and has content
    if [[ -f "$output_file" && -s "$output_file" ]]; then
        local count=$(wc -l < "$output_file")
        ((PROCESSED_LINES += count))
        
        local line_percent=0
        if [[ $TOTAL_LINES -gt 0 ]]; then
            line_percent=$((PROCESSED_LINES * 100 / TOTAL_LINES))
        fi
        local lines_remaining=$((TOTAL_LINES - PROCESSED_LINES))
        
        # Calculate lines ETA
        local current_time=$(date +%s)
        local elapsed=$((current_time - START_TIME))
        local line_eta_str="calculating..."
        local line_speed_str=""
        
        if [[ $elapsed -gt 0 && $PROCESSED_LINES -gt 0 ]]; then
            # Calculate lines per second
            local lines_per_sec=$((PROCESSED_LINES / elapsed))
            
            if [[ $lines_per_sec -gt 0 ]]; then
                # Estimate remaining time based on lines
                local line_eta_seconds=$((lines_remaining / lines_per_sec))
                line_eta_str=$(format_duration $line_eta_seconds)
                line_speed_str="${lines_per_sec} lines/s"
            else
                # Less than 1 line per second
                local secs_per_line=$((elapsed / PROCESSED_LINES))
                line_speed_str="${secs_per_line}s/line"
                local line_eta_seconds=$((lines_remaining * secs_per_line))
                line_eta_str=$(format_duration $line_eta_seconds)
            fi
        fi
        
        echo -e "${GREEN}✓ Extracted $count lines [Lines: $PROCESSED_LINES/$TOTAL_LINES - ${line_percent}%] ($lines_remaining left) [ETA: $line_eta_str, Speed: $line_speed_str] to: $(basename "$output_file")${NC}"
        ((MATCH_COUNT++))
    else
        # Fail if a matching input file did not produce output
        echo -e "${RED}Error: Expected output not created for $rel_path${NC}" >&2
        exit 1
    fi
}

##############################################################################
# Print processing statistics
##############################################################################
print_statistics() {
    # Calculate total time
    local end_time=$(date +%s)
    local total_time=$((end_time - START_TIME))
    local duration_str=$(format_duration $total_time)

    # Print summary
    echo ""
    echo -e "${YELLOW}================================${NC}"
    echo -e "${YELLOW}Processing Summary:${NC}"
    echo -e "${YELLOW}  Total files scanned: $TOTAL_FILES${NC}"
    echo -e "${YELLOW}  Total zip files scanned: $TOTAL_ZIP_FILES${NC}"
    echo -e "${YELLOW}  Total gz files scanned: $TOTAL_GZ_FILES${NC}"
    echo -e "${YELLOW}  Total tar files scanned: $TOTAL_TAR_FILES${NC}"
    echo -e "${YELLOW}  Files skipped: $SKIPPED_COUNT${NC}"
    echo ""
    echo -e "${YELLOW}File Statistics:${NC}"
    echo -e "${YELLOW}  Files processed: $PROCESSED_FILES out of $TOTAL_FILES (100%)${NC}"

    echo ""
    echo -e "${YELLOW}Line Statistics:${NC}"
    if [[ $TOTAL_LINES -gt 0 ]]; then
        local line_percent=$((PROCESSED_LINES * 100 / TOTAL_LINES))
        local lines_not_extracted=$((TOTAL_LINES - PROCESSED_LINES))
        local not_extracted_percent=$((100 - line_percent))
        echo -e "${GREEN}  Lines extracted: $PROCESSED_LINES out of $TOTAL_LINES (${line_percent}%)${NC}"
        echo -e "${YELLOW}  Lines not extracted: $lines_not_extracted ($not_extracted_percent%)${NC}"
    else
        echo -e "${YELLOW}  No lines processed${NC}"
    fi

    echo ""
    echo -e "${YELLOW}Time Statistics:${NC}"
    echo -e "${YELLOW}  Total processing time: $duration_str${NC}"
    if [[ $total_time -gt 0 ]]; then
        if [[ $PROCESSED_FILES -gt 0 ]]; then
            local avg_time_per_file=$((total_time / PROCESSED_FILES))
            echo -e "${YELLOW}  Average time per file: $(format_duration $avg_time_per_file)${NC}"
        fi
        if [[ $PROCESSED_LINES -gt 0 ]]; then
            local lines_per_sec=$((PROCESSED_LINES / total_time))
            if [[ $lines_per_sec -gt 0 ]]; then
                echo -e "${YELLOW}  Processing speed: $lines_per_sec lines/second${NC}"
            else
                local secs_per_line=$((total_time / PROCESSED_LINES))
                echo -e "${YELLOW}  Processing speed: ${secs_per_line}s per line${NC}"
            fi
        fi
    fi

    echo ""
    if [[ $MATCH_COUNT -eq 0 ]]; then
        echo -e "${YELLOW}  No matching complete entries extracted.${NC}"
    else
        echo -e "${GREEN}  ✓ Successfully processed $MATCH_COUNT file(s)${NC}"
        echo -e "${GREEN}  ✓ Total matched entries extracted: $ENTRY_COUNT${NC}"
        echo -e "${GREEN}  ✓ Results saved to: $OUTPUT_DIR${NC}"
    fi
    echo -e "${YELLOW}================================${NC}"
}

##############################################################################
# Remove files that don't contain pattern (except .zip or .gz)
# Also increase counts such as skipped, total file and line count
##############################################################################
rm_files_not_matching_pattern_update_statistics() {
    local directory="$1"
    local removed_count=0
    local kept_count=0
    
    echo -e "${BLUE}Scanning for files without pattern to remove...${NC}"
    
    # Find all files except archives
    find "$directory" -type f -print0 2>/dev/null | while IFS= read -r -d '' file; do
        local rel_path="${file#$directory/}"

        # Skip archive files
        if is_archive_mime "$file"; then
            continue
        fi
        
        # Check if file contains pattern
        if ! file_has_pattern "$file"; then
            # Remove file without pattern
            if rm -f "$file" 2>/dev/null; then
                ((removed_count++))
                if [[ "$VERBOSE" == true ]]; then
                    echo -e "${YELLOW}✗ Removed (no pattern): $rel_path${NC}"
                fi
            else
                if [[ "$VERBOSE" == true ]]; then
                    echo -e "${RED}✗ Failed to remove: $rel_path${NC}"
                fi
            fi
        else
            ((kept_count++))
            if [[ "$VERBOSE" == true ]]; then
                echo -e "${GREEN}✓ Kept (has pattern): $rel_path${NC}"
            fi
        fi
    done || true
    
    # Remove empty nested directories recursively
    local dirs_removed=0
    find "$directory" -type d -empty -print0 2>/dev/null | while IFS= read -r -d '' dir; do
        if [[ -d "$dir" ]]; then
            if rmdir "$dir" 2>/dev/null; then
                ((dirs_removed++))
                if [[ "$VERBOSE" == true ]]; then
                    local rel_path="${dir#$directory/}"
                    echo -e "${YELLOW}✗ Removed empty directory: $rel_path${NC}"
                fi
            fi
        fi
    done || true
    
    if [[ "$VERBOSE" == true ]]; then
        echo -e "${YELLOW}Cleanup Summary:${NC}"
        echo -e "${YELLOW}  Files removed: $removed_count${NC}"
        echo -e "${YELLOW}  Files kept: $kept_count${NC}"
        echo -e "${YELLOW}  Empty directories removed: $dirs_removed${NC}"
    fi
    
    # Increase statistics
    ((SKIPPED_COUNT += removed_count))
    ((TOTAL_FILES += removed_count))
    ((TOTAL_FILES += kept_count))
    
    # Increase how many lines has to be processed
    local total_lines=0
    while IFS= read -r -d '' file; do
        if ! is_archive_mime "$file"; then
            local file_lines=$(wc -l < "$file" 2>/dev/null || echo 0)
            if [[ "$file_lines" =~ ^[0-9]+$ ]]; then
                total_lines=$((total_lines + file_lines))
            fi
        fi
    done < <(find "$directory" -type f -print0 2>/dev/null)
    ((TOTAL_LINES += total_lines))
}

##############################################################################
# Find and process files in a directory (regular/zip/gz)
##############################################################################
process_files_in_dir() {
    local base_dir="$1"
    local rel_prefix="$2"

    find "$base_dir" -type f -print0 2>/dev/null | while IFS= read -r -d '' file; do
        local rel_path="${file#$base_dir/}"
        local mime_type=$(get_mime_type "$file")

        if [[ -n "$rel_prefix" ]]; then
            rel_path="$rel_prefix/$rel_path"
        fi

        ((PROCESSED_FILES++))

        case "$mime_type" in
            application/zip)
                # Recursively process nested zip files
                process_zip "$file" "$rel_path"
                ;;
            application/x-tar)
                # Process tar archives
                process_tar "$file" "$rel_path"
                ;;
            application/gzip)
                # Process gzip or tar.gz archives
                if is_tar_gz_archive "$file"; then
                    process_tar_gz "$file" "$rel_path"
                else
                    process_gz "$file" "$rel_path"
                fi
                ;;
            *)
                # Process regular files
                if [[ -f "$file" ]]; then
                    process_unzipped "$file" "$rel_path"
                fi
                ;;
        esac
    done || true
}

##############################################################################
# Process tar files
##############################################################################
process_tar() {
    local tar_file="$1"
    local rel_path="$2"

    ((TOTAL_TAR_FILES++))
    echo -e "${BLUE} Processing tar $TOTAL_TAR_FILES: $tar_file${NC}"

    if ! tar_file_has_pattern "$tar_file"; then
        ((SKIPPED_COUNT++))
        return
    fi

    local temp_dir=$(mktemp -d)
    if [[ "$VERBOSE" == true ]]; then
        echo -e "${BLUE} Created temp dir for tar: $temp_dir${NC}"
    fi

    if ! tar -xf "$tar_file" -C "$temp_dir" 2>/dev/null; then
        if [[ "$VERBOSE" == true ]]; then
            echo -e "${YELLOW}⊘ Failed to extract tar: $rel_path${NC}"
        fi
        rm -rf "$temp_dir"
        return
    fi

    rm_files_not_matching_pattern_update_statistics "$temp_dir"
    process_files_in_dir "$temp_dir" "$rel_path"

    rm -rf "$temp_dir"

    print_statistics
}

##############################################################################
# Process tar.gz or tgz files
##############################################################################
process_tar_gz() {
    local tar_file="$1"
    local rel_path="$2"

    ((TOTAL_TAR_FILES++))
    echo -e "${BLUE} Processing tar.gz $TOTAL_TAR_FILES: $tar_file${NC}"

    if ! tar_gz_file_has_pattern "$tar_file"; then
        ((SKIPPED_COUNT++))
        return
    fi

    local temp_dir=$(mktemp -d)
    if [[ "$VERBOSE" == true ]]; then
        echo -e "${BLUE} Created temp dir for tar.gz: $temp_dir${NC}"
    fi

    if ! tar -xzf "$tar_file" -C "$temp_dir" 2>/dev/null; then
        if [[ "$VERBOSE" == true ]]; then
            echo -e "${YELLOW}⊘ Failed to extract tar.gz: $rel_path${NC}"
        fi
        rm -rf "$temp_dir"
        return
    fi

    rm_files_not_matching_pattern_update_statistics "$temp_dir"
    process_files_in_dir "$temp_dir" "$rel_path"

    rm -rf "$temp_dir"

    print_statistics
}

##############################################################################
# Process gz files
##############################################################################
process_gz() {
    local gz_file="$1"
    local rel_path="$2"
    ((TOTAL_GZ_FILES++))
    echo -e "${BLUE} Processing gz $TOTAL_GZ_FILES: $gz_file${NC}"


    # Check if pattern exists in zip using zipgrep
    if ! gz_file_has_pattern "$gz_file"; then
        ((SKIPPED_COUNT++))
        return
    fi
    

    # Create temporary directory for extraction
    local temp_dir=$(mktemp -d)
    if [[ "$VERBOSE" == true ]]; then
        echo -e "${BLUE} Created temp dir for gz: $temp_dir${NC}"
    fi

    # Extract zip file contents to temporary directory
    if ! gunzip -q "$gz_file" -d "$temp_dir" 2>/dev/null; then
        if [[ "$VERBOSE" == true ]]; then
            echo -e "${YELLOW}⊘ Failed to extract gz: $rel_path${NC}"
        fi
        rm -rf "$temp_dir"
        return
    fi
    
    # Remove the not matching files
    rm_files_not_matching_pattern_update_statistics "$temp_dir"

    # Process extracted contents recursively
    process_files_in_dir "$temp_dir" "$rel_path"
    
    # Clean up temporary directory
    rm -rf "$temp_dir"

    print_statistics
}

##############################################################################
# Process zip files recursively
##############################################################################
process_zip() {
    local zip_file="$1"
    local rel_path="$2"

    ((TOTAL_ZIP_FILES++))
    echo -e "${BLUE} Processing zip $TOTAL_ZIP_FILES: $zip_file${NC}"
    

    # Check if pattern exists in zip using zipgrep
    if ! zip_file_has_pattern "$zip_file"; then
        ((SKIPPED_COUNT++))
        return
    fi

    # Create temporary directory for extraction
    local temp_dir=$(mktemp -d)
    if [[ "$VERBOSE" == true ]]; then
        echo -e "${BLUE} Created temp dir for zip: $temp_dir${NC}"
    fi

    # Extract zip file contents to temporary directory
    if ! unzip -q "$zip_file" -d "$temp_dir" 2>/dev/null; then
        if [[ "$VERBOSE" == true ]]; then
            echo -e "${YELLOW}⊘ Failed to extract zip: $rel_path${NC}"
        fi
        rm -rf "$temp_dir"
        return
    fi
    
    # Remove the not matching files
    rm_files_not_matching_pattern_update_statistics "$temp_dir"

    # Process extracted contents recursively
    process_files_in_dir "$temp_dir" "$rel_path"
    
    # Clean up temporary directory
    rm -rf "$temp_dir"

    print_statistics
}

##############################################################################
# Main search function
##############################################################################
search_patterns() {
    echo -e "${YELLOW}Pattern Matching Configuration:${NC}"
    echo -e "${YELLOW}  Pattern: '$PATTERN'${NC}"
    echo -e "${YELLOW}  Input directory: $INPUT_DIR${NC}"
    echo -e "${YELLOW}  Output directory: $OUTPUT_DIR${NC}"
    echo -e "${YELLOW}  Timestamp regex: $TIMESTAMP_REGEX${NC}"
    echo -e "${YELLOW}  Verbose: $VERBOSE${NC}"
    echo ""
    
    # Count total files first for percentage calculation
    echo -e "${BLUE}Counting total files...${NC}"
    TOTAL_FILES=$(find "$INPUT_DIR" -type f | wc -l)
    # Count total lines first for percentage calculation
    local total_lines=0
    while IFS= read -r -d '' file; do
        if ! is_archive_mime "$file"; then
            local file_lines=$(wc -l < "$file" 2>/dev/null || echo 0)
            if [[ "$file_lines" =~ ^[0-9]+$ ]]; then
                total_lines=$((total_lines + file_lines))
            fi
        fi
    done < <(find "$INPUT_DIR" -type f -print0 2>/dev/null)
    ((TOTAL_LINES += total_lines))

    echo -e "${BLUE}Found $TOTAL_FILES file(s) to scan${NC}"
    echo ""
    
    # Record start time
    START_TIME=$(date +%s)
    echo -e "${BLUE}Started processing at: $(date '+%Y-%m-%d %H:%M:%S')${NC}"
    echo ""


    # Find and process all files
    process_files_in_dir "$INPUT_DIR" ""

    print_statistics
}

##############################################################################
# Main execution
##############################################################################
main() {
    parse_args "$@"
    validate_inputs
    search_patterns
}

main "$@"