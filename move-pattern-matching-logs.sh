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
MATCH_COUNT=0
ENTRY_COUNT=0
SKIPPED_COUNT=0
VERBOSE=false
PROCESSED_FILES=0
TOTAL_FILES=0
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
    grep -q "$PATTERN" "$file" 2>/dev/null
}

##############################################################################
# Check if zip file contains pattern (using zipgrep)
##############################################################################
zipfile_has_pattern() {
    local zipfile="$1"
    zipgrep -q "$PATTERN" "$zipfile" 2>/dev/null
}

##############################################################################
# Extract and filter complete log entries
##############################################################################
extract_and_filter_entries() {
    local input_file="$1"
    local output_file="$2"
    
    # Use grep to find line numbers matching the pattern (FAST!)
    local pattern_lines
    pattern_lines=$(grep -n "$PATTERN" "$input_file" 2>/dev/null | cut -d: -f1)
    
    if [[ -z "$pattern_lines" ]]; then
        # No matches found in this file
        return
    fi
    
    # Use grep to find line numbers starting with timestamp (entry boundaries)
    local timestamp_lines
    timestamp_lines=$(grep -n "$TIMESTAMP_REGEX" "$input_file" 2>/dev/null | cut -d: -f1)
    
    if [[ -z "$timestamp_lines" ]]; then
        # No timestamp entries found, process entire file if pattern matches
        cat "$input_file" >> "$output_file"
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
    local total_lines
    total_lines=$(wc -l < "$input_file")
    
    # Convert timestamp_lines to array for binary search
    local -a ts_array
    while IFS= read -r line; do
        ts_array+=("$line")
    done <<< "$timestamp_lines"
    
    # Extract and write complete entries
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
        
        # Extract lines from entry_start to entry_end using sed (faster than while loop)
        sed -n "${entry_start},${entry_end}p" "$input_file" >> "$output_file"
        ((ENTRY_COUNT++))
    done
}

##############################################################################
# Process unzipped log files
##############################################################################
process_unzipped() {
    local input_file="$1"
    local rel_path="$2"
    
    # Count lines in this file
    local file_lines
    file_lines=$(wc -l < "$input_file" 2>/dev/null || echo 0)
    ((TOTAL_LINES += file_lines))
    
    # Filter files: skip if pattern not found (optimization for huge directories)
    if ! file_has_pattern "$input_file"; then
        if [[ "$VERBOSE" == true ]]; then
            echo -e "${YELLOW}⊘ Skipped (no pattern match): $rel_path${NC}"
        fi
        ((SKIPPED_COUNT++))
        return
    fi
    
    local output_file="$OUTPUT_DIR/$rel_path"
    
    # Create output directory structure
    mkdir -p "$(dirname "$output_file")"
    
    # Calculate and show progress percentages
    ((PROCESSED_FILES++))
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
        local count
        count=$(wc -l < "$output_file")
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
        # Remove empty output file
        rm -f "$output_file"
    fi
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
    echo -e "${BLUE}Found $TOTAL_FILES file(s) to scan${NC}"
    echo ""
    
    # Record start time
    START_TIME=$(date +%s)
    echo -e "${BLUE}Started processing at: $(date '+%Y-%m-%d %H:%M:%S')${NC}"
    echo ""

    local total_files=0
    local filtered_files=0

    # Find and process all files
    while IFS= read -r -d '' file; do
        ((total_files++))
        
        # Calculate relative path from INPUT_DIR
        local rel_path
        rel_path="${file#$INPUT_DIR/}"
        
        case "$file" in
            *.zip)
                # Filter zip files: check if pattern exists using zipgrep
                if ! zipfile_has_pattern "$file"; then
                    if [[ "$VERBOSE" == true ]]; then
                        echo -e "${YELLOW}⊘ Skipped (no pattern match): $rel_path${NC}"
                    fi
                    ((SKIPPED_COUNT++))
                    continue
                fi
                ((filtered_files++))
                
                # For zip files, extract to temp, process, then clean up
                local temp_dir
                temp_dir=$(mktemp -d)
                unzip -q "$file" -d "$temp_dir" 2>/dev/null || true
                find "$temp_dir" -type f | while read -r extracted_file; do
                    local extracted_rel_path
                    extracted_rel_path="${extracted_file#$temp_dir/}"
                    process_unzipped "$extracted_file" "$rel_path/$extracted_rel_path"
                done
                rm -rf "$temp_dir"
                ;;
            *)
                # Process regular files
                if [[ -f "$file" ]]; then
                    ((filtered_files++))
                    process_unzipped "$file" "$rel_path"
                fi
                ;;
        esac
    done < <(find "$INPUT_DIR" -type f -print0)

    # Calculate total time
    local end_time=$(date +%s)
    local total_time=$((end_time - START_TIME))
    local duration_str=$(format_duration $total_time)
    
    # Print summary
    echo ""
    echo -e "${YELLOW}================================${NC}"
    echo -e "${YELLOW}Processing Summary:${NC}"
    echo -e "${YELLOW}  Total files scanned: $total_files${NC}"
    echo -e "${YELLOW}  Files with pattern matches: $filtered_files${NC}"
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
# Main execution
##############################################################################
main() {
    parse_args "$@"
    validate_inputs
    search_patterns
}

main "$@"
