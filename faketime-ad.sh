#!/usr/bin/bash
# ==========================================================
# Function: run_faketime
# Description: Executes a command using faketime, synchronized
#              to the 'smb2-time' reported by a specified IP,
#              adjusting for the local machine's timezone.
# Usage: ./faketime-ad.sh <target_ip> <your_command_and_arguments>
#        e.g. ./faketime-ad.sh 10.0.0.1 date
# ==========================================================
function run_faketime() {    
    # 0. Check if proxychains is active and enforce root
    # Detect proxychains via typical env vars:
    #  - LD_PRELOAD containing "proxychains"
    #  - PROXYCHAINS_CONF_FILE being set
    PROXYCHAINS_ACTIVE=0
    if [[ "${LD_PRELOAD:-}" == *proxychains* ]] || [[ -n "${PROXYCHAINS_CONF_FILE:-}" ]]; then
        PROXYCHAINS_ACTIVE=1
    fi

    if (( PROXYCHAINS_ACTIVE )) && [[ "$EUID" -ne 0 ]]; then
        echo "🚨 Detected proxychains in the environment, but you are not root (EUID=$EUID)."
        echo "    'proxychains4 nmap' requires root. Please re-run as:"
        echo "        sudo proxychains4 $0 <target_ip> <your_command_and_arguments>"
        echo "    or start a root shell (sudo su) and run the command there."
        return 1
    fi

    # 0b. Check that faketime is available
    if ! command -v faketime >/dev/null 2>&1; then
        echo "🚨 ERROR: 'faketime' (libfaketime) is not installed or not in PATH."
        echo "    Please install libfaketime and ensure the 'faketime' binary is available."
        echo "    Example on Debian/Ubuntu: sudo apt install faketime"
        return 1
    fi

    # 1. Check for minimum arguments (IP and command)
    if [ $# -lt 2 ]; then
        echo "Usage: run_faketime <target_ip> <your_command_and_arguments>"
        echo "Example: run_faketime 10.0.0.1 date"
        return 1
    fi

    # --- Parameter Assignment ---
    TARGET_IP="$1"
    
    # Shift arguments: remove the IP so that "$@" now contains only the command
    shift
    # Store the remaining arguments as an array to preserve spaces/quoting
    COMMAND_TO_RUN=("$@")

    # --- Time Zone Calculation (for info only) ---
    LOCAL_OFFSET_RAW=$(/bin/date +%z)
    
    if [[ "$LOCAL_OFFSET_RAW" =~ ^\+ ]]; then
        FAKETIME_OFFSET="-${LOCAL_OFFSET_RAW:1}" # Inverted sign, just for display
    elif [[ "$LOCAL_OFFSET_RAW" =~ ^\- ]]; then
        FAKETIME_OFFSET="+${LOCAL_OFFSET_RAW:1}"
    else
        FAKETIME_OFFSET="+0000"
    fi
    
    FAKETIME_OFFSET_DISPLAY="${FAKETIME_OFFSET:0:3}:${FAKETIME_OFFSET:3}"

    echo "Local Start Time (date): $(date)"
    echo "Local UTC Offset (Calculated): $FAKETIME_OFFSET_DISPLAY"
    echo "1. ⚙️ Running Nmap on $TARGET_IP to retrieve remote time..."

    # 2. Execute Nmap and extract the 'date:' value (UTC).
    TARGET_TIME_RAW=$(
        nmap -p 445 --script smb2-time -Pn -sT -n "$TARGET_IP" 2>/dev/null \
        | awk '/\|   date:/ {print $3}' \
        | tr -d '\r'
    )

    # 3. Validation
    if [ -z "$TARGET_TIME_RAW" ]; then
        echo "🚨 ERROR: Could not extract smb2-time from $TARGET_IP. Nmap output was empty or script failed."
        return 1
    fi
    
    # 4. Convert Nmap's format (YYYY-MM-DDTHH:MM:SS) to "YYYY-MM-DD HH:MM:SS"
    TARGET_TIME_CLEAN=$(echo "$TARGET_TIME_RAW" | tr 'T' ' ')
    echo "2. ✅ Target UTC Time Extracted: $TARGET_TIME_CLEAN"

    # 5. Convert the remote UTC time to local time
    TARGET_TS=$(date -u -d "$TARGET_TIME_CLEAN" +%s 2>/dev/null)
    if [ -z "$TARGET_TS" ]; then
        echo "🚨 ERROR: Failed to parse target time: $TARGET_TIME_CLEAN"
        return 1
    fi

    FAKETIME_LOCAL=$(date -d "@$TARGET_TS" "+%Y-%m-%d %H:%M:%S")
    echo "   Converted to local time:     $FAKETIME_LOCAL"

    echo "3. 🚀 Executing command with faketime at local-equivalent time..."
    
    # faketime expects "YYYY-MM-DD HH:MM:SS"
    FAKETIME_ARG="$FAKETIME_LOCAL"
    
    echo -n "   Faketime Command: faketime '$FAKETIME_ARG'"
    printf ' %q' "${COMMAND_TO_RUN[@]}"
    echo
    echo "---------------------------------------------------------"

    # 6. Run faketime, preserving all original arguments (including 'ipconfig /all')
    faketime "$FAKETIME_ARG" "${COMMAND_TO_RUN[@]}"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    run_faketime "$@"
fi
