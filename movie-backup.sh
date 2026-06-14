#!/usr/bin/env bash

# Safety flags: Exit immediately if a command fails, or if an uninitialized variable is used.
set -euo pipefail

# --- CONFIGURATION ---
# Default folders to back up if no specific folder is passed via CLI.
SOURCES=(
    "$HOME/Movies"
)

# Default target backup directory
DESTINATION="/Volumes/tbyte/YouTube"
LOG_FILE="$HOME/Library/Logs/rsync_backup.log"

# --- DEFAULT CONFIG (Flags override these) ---
DRY_RUN=false
PURGE=false
AUTOMATED=false

# --- HELP MENU ---
usage() {
    cat << EOF
Usage: $(basename "$0") [options]

A robust rsync backup script for macOS.

Options:
  -s, --source <path>       Specify a custom folder to sync (overrides default list).
  -d, --destination <path>  Specify a custom destination folder (overrides default).
  -n, --dry-run             Show what would be transferred without making changes.
  -p, --purge               Delete files in destination that no longer exist in source.
  -a, --automated           Run silently (no prompts, optimized for cron/launchd).
  -h, --help                Display this help menu.

Examples:
  $(basename "$0") -n
  $(basename "$0") --source ~/Projects --destination /Volumes/USB_Drive/Backups
  $(basename "$0") -s ~/Desktop -d /Volumes/SecureDrive/DesktopBackup -p
EOF
}

# --- ARGUMENT PARSING ---
while [[ $# -gt 0 ]]; do
    case "$1" in
        -s|--source)
            if [[ -n "${2:-}" && ! "$2" =~ ^- ]]; then
                SOURCES=("$2")
                shift 2
            else
                echo "Error: Option $1 requires a valid directory path." >&2
                exit 1
            fi
            ;;
        -d|--destination)
            if [[ -n "${2:-}" && ! "$2" =~ ^- ]]; then
                DESTINATION="$2"
                shift 2
            else
                echo "Error: Option $1 requires a valid directory path." >&2
                exit 1
            fi
            ;;
        -n|--dry-run)   DRY_RUN=true; shift ;;
        -p|--purge)     PURGE=true; shift ;;
        -a|--automated) AUTOMATED=true; shift ;;
        -h|--help)      usage; exit 0 ;;
        *)              echo "Error: Unknown option $1" >&2; usage; exit 1 ;;
    esac
done

# --- PRE-FLIGHT CHECKS ---
# Ensure destination directory exists or can be created (e.g., if the drive is mounted)
if ! mkdir -p "$DESTINATION" 2>/dev/null; then
    echo "Error: Cannot create or access destination '$DESTINATION'. Is the drive mounted?" >&2
    exit 1
fi

# Dynamic Rsync Flag Selection (Detecting Homebrew rsync vs. Apple default)
RSYNC_FLAGS="-ahv"

if rsync --version | grep -q "version 3"; then
    # Homebrew Rsync (v3+) optimizations for macOS metadata
    RSYNC_FLAGS="-ahvHAX --protect-args"
else
    if [ "$AUTOMATED" = false ]; then
        echo "⚠️ Warning: Using macOS default rsync. Consider running 'brew install rsync' for better metadata support."
    fi
    RSYNC_FLAGS="-ahvE"
fi

# Append flags based on user choices
if [ "$DRY_RUN" = true ]; then
    RSYNC_FLAGS="$RSYNC_FLAGS --dry-run"
    echo "🔍 DRY RUN MODE ACTIVATED. No files will be modified."
fi

if [ "$PURGE" = true ]; then
    RSYNC_FLAGS="$RSYNC_FLAGS --delete"
fi

# Standard exclusions to keep the backup clean
EXCLUDES=(
    --exclude='.DS_Store'
    --exclude='.Trash'
    --exclude='node_modules/'
    --exclude='.cache'
)

# --- EXECUTION ---
log_message() {
    local message="$1"
    if [ "$AUTOMATED" = true ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') : $message" >> "$LOG_FILE"
    else
        echo -e "$message"
    fi
}

log_message "🚀 Starting backup sync at $(date)"

for source_dir in "${SOURCES[@]}"; do
    if [ ! -d "$source_dir" ]; then
        log_message "⚠️ Skipping: Source folder '$source_dir' does not exist."
        continue
    fi

    log_message "🔄 Syncing: $source_dir ➡️ $DESTINATION"
    
    # Run rsync
    if [ "$AUTOMATED" = true ]; then
        rsync $RSYNC_FLAGS "${EXCLUDES[@]}" "$source_dir" "$DESTINATION" >> "$LOG_FILE" 2>&1
    else
        rsync $RSYNC_FLAGS --progress "${EXCLUDES[@]}" "$source_dir" "$DESTINATION"
    fi
done

log_message "✅ Backup process completed successfully at $(date)."