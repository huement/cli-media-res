#!/usr/bin/env bash

# ▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔
# ██╗  ██╗██╗   ██╗███████╗███╗   ███╗███████╗███╗   ██╗████████╗
# ██║  ██║██║   ██║██╔════╝████╗ ████║██╔════╝████╗  ██║╚══██╔══╝
# ███████║██║   ██║█████╗  ██╔████╔██║█████╗  ██╔██╗ ██║   ██║
# ██╔══██║██║   ██║██╔══╝  ██║╚██╔╝██║██╔══╝  ██║╚██╗██║   ██║
# ██║  ██║╚██████╔╝███████╗██║ ╚═╝ ██║███████╗██║ ╚████║   ██║
# ╚═╝  ╚═╝ ╚═════╝ ╚══════╝╚═╝     ╚═╝╚══════╝╚═╝  ╚═══╝   ╚═╝
# ▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁
#
# TITLE:    tone.sh
# DETAILS:  This is just a test
# AUTHOR:   derek@huement.com
# VERSION:  0.0.1
# DATE:     2022-12-31_19
#
# ▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔
#% Allows you to move images into folders based on file size and/or extension.
#% Additionally cleans up file extension capitalization errors, and removes
#% duplicate files. Will also zip the result for easy transfer.
#%
#% Make sure you pass any options first. such as -e or -i flags.
#%
#% EXAMPLE: ./${SCRIPT_NAME} -e -i -s ./new-cat-files -t ~/Pictures/category
#%
#% OPTIONS:
#%    -d|--dedupe)
#%       Remove any duplicates (requires 'fdupes' package)
#%    -e|--extensions)
#%       Sort by Raster / Vector categories on the end result
#%    -i|--icons)
#%       Filter out icons from end result
#%    -m|--merge <DIR>)
#%       Rsync Merge into given directory
#%    -p|--pack)
#%       Package the end result into a .zip archive saved to target directory
#%    -s|--sort <DIR>)
#%       Sort the images in given Directory
#%    -t|--target <DIR>)
#%       Where to put the sorted images. If not given ~/Pictures is used
#%
#% HELP:
#%    -h|-?|--help)
#%       show this help and exit
#%
#%
# ▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁
#-
#- IMPLEMENTATION
#-    version         ${SCRIPT_NAME} (www.huement.com) 0.0.1
#-    author          Derek Scott
#-    copyright       Copyright (c) http://www.huement.com
#-    license         GNU General Public License
#-    script_id       12345
#-
# ▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔
#  HISTORY
#     2022/12/01 : johnnyfortune : Script creation
#
# ▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔
#                Made with L<3VE from Huement.com
# ▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁



# FLAGS + DEFAULTS + SPECIFIC SCRIPT ITEMS
## ------------------ ---------  ------   ----    ---     --      -
# [R]un [A]s [R]oot?
RAR="false"

# Common
LOGFILE="${HOME}/logs/$(basename "$0").log"
LOGMSG=1 # 0 = false, 1 = true

declare -a ARGS=()

NOW=$(LC_ALL=C date +"%m-%d-%Y %r")                   # Returns: 06-14-2015 10:34:40 PM
DATESTAMP=$(LC_ALL=C date +%Y-%m-%d)                  # Returns: 2015-06-14
HOURSTAMP=$(LC_ALL=C date +%r)                        # Returns: 10:34:40 PM
TIMESTAMP=$(LC_ALL=C date +%Y%m%d_%H%M%S)             # Returns: 20150614_223440
LONGDATE=$(LC_ALL=C date +"%a, %d %b %Y %H:%M:%S %z") # Returns: Sun, 10 Jan 2016 20:47:53 -0500
GMTDATE=$(LC_ALL=C date -u -R | sed 's/\+0000/GMT/')  # Returns: Wed, 13 Jan 2016 15:55:29 GMT

SCRIPT_HEADSIZE=$(head -200 ${0} | grep -n "^# END_OF_HEADER" | cut -f1 -d:)
SCRIPT_NAME="$(basename ${0})"


# SCRIPT DEFAULT VARS
## ------------------ ---------  ------   ----    ---     --      -
SCRIPT=$(realpath -s "$0")
SCRIPTPATH=$(dirname "$SCRIPT")

source "${SCRIPTPATH}"/lib.sh
source "${SCRIPTPATH}"/imgfunctions.sh

DU=/usr/local/bin/gdu
TARGET_DIR="${HOME}/Pictures"
PACK_FLAG=0
SORT_FLAG=0
DEDUPE_FLAG=0
EXT_FLAG=0
ICON_FLAG=0
PARAMS=""

# SCRIPT FUNCTIONALITY
## ------------------ ---------  ------   ----    ---     --      -

_mainAction_() {

	#DICE=$(awk 'BEGIN {srand(); print int(6 * rand()) + 1}')
	#PMSG "DONE" "${BCYN}You Rolled a ${BPUR}${DICE}${NORMAL}"

	#echo -e "\n"
	
  if [[ "$SORT_FLAG" -eq 1 ]]; then
      PMSG "INFO" "Starting Image Sort"
      sortImages
  fi

  if [[ "$DEDUPE_FLAG" -eq 1 ]]; then
      PMSG "INFO" "Starting Deduplication"
      removeDupes "$TARGET_DIR"
  fi

  if [[ "$ICON_FLAG" -eq 1 ]]; then
      PMSG "INFO" "Starting Icon Filtering"
      filterIcons
  fi

  if [[ "$PACK_FLAG" -eq 1 ]]; then
      PMSG "INFO" "Starting Image Compression"
      packItUp "$TARGET_DIR"
  fi

  PMSG "GOOD" "Script Finished!"
}

# SCRIPT SETUP
## ------------------ ---------  ------   ----    ---     --      -

traperr() {
	PMSG "FAIL" "ERROR: ${BASH_SOURCE[1]} at about ${BASH_LINENO[0]}"
}

# Set IFS to preferred implementation
IFS=$' \n\t'

set -e
set -o pipefail
set -o errtrace
trap traperr ERR
set -o nounset

shopt -s nocaseglob             # Case-insensitive globbing (used in pathname expansion)
shopt -s globstar 2>/dev/null   # Recursive globbing (enables ** to recurse all directories)
shopt -s dotglob                # Include dotfiles in pathname expansion
shopt -s expand_aliases         # Expand aliases
shopt -s extglob                # Enable extended pattern-matching features

# Create a temp directory '$TMP_DIR'
# _makeTempDir_ "$(basename "$0")"

_setColors_
_setMessages_
_scriptHeader_

# Parse arguments passed to script

# Force arguments when invoking the script
if [[ $# -eq 0 ]]; then
	PMSG "WARN" "You must atleast set the target directory to sort ya dingus!"
	echo ""
	usagefull >&2
	_safeExit_
else
	if [ "$RAR" != "false" ]; then
		run_as_root
	fi

	# Iterate over options
	# breaking -ab into -a -b when needed and --foo=bar into --foo bar
	optstring=h
	unset options
	while (($#)); do
		case $1 in
		# If option is of type -ab
		-[!-]?*)
			# Loop over each character starting with the second
			for ((i = 1; i < ${#1}; i++)); do
				c=${1:i:1}
				options+=("-$c") # Add current char to options
				# If option takes a required argument, and it's not the last char make
				# the rest of the string its argument
				if [[ $optstring == *"$c:"* && ${1:i+1} ]]; then
					options+=("${1:i+1}")
					break
				fi
			done
			;;
		# If option is of type --foo=bar
		--?*=*) options+=("${1%%=*}" "${1#*=}") ;;
		# add --endopts for --
		--) options+=(--endopts) ;;
		# Otherwise, nothing special
		*) options+=("$1") ;;
		esac
		shift
	done
	set -- "${options[@]:-}"
	unset options

	# Read the options and set stuff
	while [[ ${1:-} == -?* ]]; do
		case $1 in
			# Custom options
		  -p | --pack)
				shift
		    PACK_FLAG=1
		    PMSG "INFO" "Compression Set"
		    #packItUp "$TARGET_DIR"
		    ;;
		  -d | --dedupe)
				shift
		    DEDUPE_FLAG=1
		    PMSG "INFO" "Deduplication Set"
		    #removeDupes "$TARGET_DIR"
		    ;;
		  -e | --extensions)
				shift
		    EXT_FLAG=1
		    PMSG "INFO" "Extension Sort Set"
		    ;;
		  -i | --icons)
				shift
		    ICON_FLAG=1
		    PMSG "INFO" "Icon Filter Set"
		    ;;
		  -t | --target)
				shift
		    TARGET_DIR="${1}"
		    # if [ -n "$2" ] && [ ${2:0:1} != "-" ]; then
		    #     TARGET_DIR=$2
		    #     shift 2
		    # else
		    #     die "$1 is missing path option!" >&2
		    # fi
		    PMSG "INFO" "Saving to: ${TARGET_DIR}"
		    ;;
		  -s | --sort)
				shift
		    SORT_FLAG=1
		    IMGPATH="${1}"
		    ;;
		  -m | --merge)
				shift
		    RDest="${1}"
		    PMSG "INFO" "Merging Results into ${RDest}"
		    ;;
			# Common options
			-h | --help)
				echo ""
				usagefull >&2
				_safeExit_
				;;
			--loglevel)
				shift
				LOGLEVEL="${1}"
				;;
			--logfile)
				shift
				LOGFILE="${1}"
				;;
			-n | --dryrun) DRYRUN=true ;;
			-v | --version)
				version >&2
				_safeExit_
				;;
			-q | --quiet) QUIET=true ;;
			--force) FORCE=true ;;
			--endopts)
				shift
				break
				;;
			*)
				PMSG "WARN" "invalid option: '$1'."
				echo ""
				usage >&2
				echo ""
				;;
		esac
			shift
	done
		ARGS+=("$@") # Store the remaining user input as arguments.
	
	# Init main Logic
	_mainAction_
fi

# Exit cleanly
_safeExit_
