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
#% EXAMPLE: ./${SCRIPT_NAME} -e -i -s ./messybunch -t ./cleanfiles
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


# Exit Script
# -----------------------------------
# Non destructive exit for when script exits naturally.
# Usage: Add this at the end of every script
# -----------------------------------
_safeExit_()
{
  if [[ -n ${TMP_DIR:-} && -d ${TMP_DIR:-} ]]; then
    if [[ ${1:-} == 1 && -n "$(ls "${TMP_DIR}")" ]]; then
      # Do something here to save TMP_DIR on a non-zero script exit for debugging
      command rm -r "${TMP_DIR}"
      PMSG "INFO" "Removing temp directory"
    else
      command rm -r "${TMP_DIR}"
      PMSG "INFO" "Removing temp directory"
    fi
  fi

  trap - INT TERM EXIT
  exit ${1:-0}
}

_makeTempDir_()
{
  # DESC:   Creates a temp directory to house temporary files
  # ARGS:   $1 (Optional) - First characters/word of directory name
  # OUTS:   $TMP_DIR       - Temporary directory
  # USAGE:  _makeTempDir_ "$(basename "$0")"

  [ -d "${TMP_DIR:-}" ] && return 0

  if [ -n "${1:-}" ]; then
        TMP_DIR="${TMPDIR:-/tmp/}${1}.$RANDOM.$RANDOM.$$"
  else
        TMP_DIR="${TMPDIR:-/tmp/}$(basename "$0").$RANDOM.$RANDOM.$RANDOM.$$"
  fi

  (umask 077 && mkdir "${TMP_DIR}") || {
        PMSG "FAIL" "Could not create temporary directory! Exiting."
  }
    debug "\$TMP_DIR=${TMP_DIR}"
}

# Run Script as Root
# -----------------------------------
# DESC: Run the requested command as root (via sudo if requested)
# ARGS: $1 (optional): Set to zero to not attempt execution via sudo
#       $@ (required): Passed through for execution as root user
# -----------------------------------
run_as_root()
{
  if [[ $(id -u) -ne 0 ]]; then
      PMSG "FAIL" "Please run as root"
      exit 1
  fi
}

# OUTPUT + UI FUNCTIONS
## ------------------ ---------  ------   ----    ---     --      -

_scriptHeader_()
{
    # Run this to generate the banner
    # figlet -f Rounded " E][AMPLE " | lolcat -f &> ban.txt
    #
    # Then run this to create the final header
    # cat ban.txt divider.txt > header.txt
    #echo -e "\n\n"
    #figlet -f Rounded " E][AMPLE " | lolcat -f
    #ruleln "X" 60 | lolcat -f
    #echo -e "\n$(rulemsg 'MADNESS')\n"
		_runbanner_
}


_runbanner_()
{
    # Run this to generate the banner
    # figlet -f Rounded " E][AMPLE " | lolcat -f &> ban.txt
    #
    # Then run this to create the final header
    # cat ban.txt divider.txt > header.txt

    echo -e "\n"
    cat <<EOF
[0;1;33;93m██[0;1;32;92m╗[0m      [0;1;35;95m█[0;1;31;91m██[0;1;33;93m██[0;1;32;92m██[0;1;36;96m╗[0m [0;1;34;94m██[0;1;35;95m██[0;1;31;91m██[0;1;33;93m╗[0m [0;1;32;92m██[0;1;36;96m██[0;1;34;94m██[0;1;35;95m╗[0m [0;1;31;91m██[0;1;33;93m██[0;1;32;92m██[0;1;36;96m██[0;1;34;94m╗█[0;1;35;95m██[0;1;31;91m██[0;1;33;93m█╗[0m
[0;1;32;92m██[0;1;36;96m║[0m      [0;1;31;91m█[0;1;33;93m█╔[0;1;32;92m╝╝[0;1;36;96m╝╝[0;1;34;94m╝█[0;1;35;95m█╔[0;1;31;91m╝╝[0;1;33;93m╝█[0;1;32;92m█╗[0;1;36;96m██[0;1;34;94m╔╝[0;1;35;95m╝█[0;1;31;91m█╗[0;1;33;93m╚╝[0;1;32;92m╝█[0;1;36;96m█╔[0;1;34;94m╝╝[0;1;35;95m╝█[0;1;31;91m█╔[0;1;33;93m╝╝[0;1;32;92m██[0;1;36;96m╗[0m
[0;1;36;96m██[0;1;34;94m║█[0;1;35;95m██[0;1;31;91m██[0;1;33;93m╗█[0;1;32;92m██[0;1;36;96m██[0;1;34;94m██[0;1;35;95m╗█[0;1;31;91m█║[0m   [0;1;32;92m█[0;1;36;96m█║[0;1;34;94m██[0;1;35;95m██[0;1;31;91m██[0;1;33;93m╔╝[0m   [0;1;36;96m█[0;1;34;94m█║[0m   [0;1;31;91m█[0;1;33;93m██[0;1;32;92m██[0;1;36;96m█╔[0;1;34;94m╝[0m
[0;1;34;94m██[0;1;35;95m║╚[0;1;31;91m╝╝[0;1;33;93m╝╝[0;1;32;92m╝╚[0;1;36;96m╝╝[0;1;34;94m╝╝[0;1;35;95m██[0;1;31;91m║█[0;1;33;93m█║[0m   [0;1;36;96m█[0;1;34;94m█║[0;1;35;95m██[0;1;31;91m╔╝[0;1;33;93m╝█[0;1;32;92m█╗[0m   [0;1;34;94m█[0;1;35;95m█║[0m   [0;1;33;93m█[0;1;32;92m█╔[0;1;36;96m╝╝[0;1;34;94m██[0;1;35;95m╗[0m
[0;1;35;95m██[0;1;31;91m║[0m      [0;1;36;96m█[0;1;34;94m██[0;1;35;95m██[0;1;31;91m██[0;1;33;93m║╚[0;1;32;92m██[0;1;36;96m██[0;1;34;94m██[0;1;35;95m╔╝[0;1;31;91m██[0;1;33;93m║[0m  [0;1;32;92m█[0;1;36;96m█║[0m   [0;1;35;95m█[0;1;31;91m█║[0m   [0;1;32;92m█[0;1;36;96m█║[0m  [0;1;35;95m██[0;1;31;91m║[0m
[0;1;31;91m╚╝[0;1;33;93m╝[0m      [0;1;34;94m╚[0;1;35;95m╝╝[0;1;31;91m╝╝[0;1;33;93m╝╝[0;1;32;92m╝[0m [0;1;36;96m╚╝[0;1;34;94m╝╝[0;1;35;95m╝╝[0;1;31;91m╝[0m [0;1;33;93m╚╝[0;1;32;92m╝[0m  [0;1;36;96m╚[0;1;34;94m╝╝[0m   [0;1;31;91m╚[0;1;33;93m╝╝[0m   [0;1;36;96m╚[0;1;34;94m╝╝[0m  [0;1;31;91m╚╝[0;1;33;93m╝[0m
EOF
    echo " "
}

_setColors_()
{
  if tput setaf 1 &>/dev/null; then

    # COLOR OPTIONS
    NORMAL="$(tput sgr0)" # Text Reset
    NC="$(tput sgr0)" # Text Reset
    BOLD="$(tput bold)" # Make Bold
    UNDERLINE="$(tput smul)" # Underline
    NOUNDER="$(tput rmul)" # Remove Underline
    BLINK="$(tput blink)" # Make Blink
    REVERSE="$(tput rev)" # Reverse

    if [[ $(tput colors) -ge 256 ]] 2>/dev/null; then
      BLK="$(tput setaf 252)" # Black
      RED="$(tput setaf 44)" # Red
      GRN="$(tput setaf 164)" # Green
      YLW="$(tput setaf 21)" # Yellow
      BLU="$(tput setaf 172)" # Blue
      PUR="$(tput setaf 184)" # Purple
      CYN="$(tput setaf 172)" # Cyan
      WHT="$(tput setaf 232)" # White
    else
      BLK="$(tput setaf 0)" # Black
      RED="$(tput setaf 1)" # Red
      GRN="$(tput setaf 2)" # Green
      YLW="$(tput setaf 3)" # Yellow
      BLU="$(tput setaf 4)" # Blue
      PUR="$(tput setaf 5)" # Purple
      CYN="$(tput setaf 6)" # Cyan
      WHT="$(tput setaf 7)" # White
    fi

    # BOLD TEXT COLORS
    BBLK="$(tput setaf 8)" # Black
    BRED="$(tput setaf 9)" # Red
    BGRN="$(tput setaf 10)" # Green
    BYLW="$(tput setaf 11)" # Yellow
    BBLU="$(tput setaf 12)" # Blue
    BPUR="$(tput setaf 13)" # Purple
    BCYN="$(tput setaf 14)" # Cyan
    BWHT="$(tput setaf 15)" # White

    # REGULAR BACKGROUND COLORS
    B_BLK="$(tput setab 0)" # Black
    B_RED="$(tput setab 1)" # Red
    B_GRN="$(tput setab 2)" # Green
    B_YLW="$(tput setab 3)" # Yellow
    B_BLU="$(tput setab 4)" # Blue
    B_PUR="$(tput setab 5)" # Purple
    B_CYN="$(tput setab 6)" # Cyan
    B_WHT="$(tput setab 7)" # White

    # BOLD BACKGROUND COLORS
    BB_BLK="$(tput setab 8)" # Black
    BB_RED="$(tput setab 9)" # Red
    BB_GRN="$(tput setab 10)" # Green
    BB_YLW="$(tput setab 11)" # Yellow
    BB_BLU="$(tput setab 12)" # Blue
    BB_PUR="$(tput setab 13)" # Purple
    BB_CYN="$(tput setab 14)" # Cyan
    BB_WHT="$(tput setab 7)" # White
  else

    # REGULAR TEXT COLORS
    BLK="\e[1;30m" # Black
    RED="\e[1;31m" # Red
    GRN="\e[1;32m" # Green
    YLW="\e[1;33m" # Yellow
    BLU="\e[1;34m" # Blue
    PUR="\e[1;35m" # Purple
    CYN="\e[1;36m" # Cyan
    WHT="\e[1;37m" # White

    # BOLD TEXT COLORS
    BBLK="\e[1;30m" # Black
    BRED="\e[1;31m" # Red
    BGRN="\e[1;32m" # Green
    BYLW="\e[1;33m" # Yellow
    BBLU="\e[1;34m" # Blue
    BPUR="\e[1;35m" # Purple
    BCYN="\e[1;36m" # Cyan
    BWHT="\e[1;37m" # White

    # BACKGROUND COLORS
    B_BLK="\e[40m" # Black
    B_RED="\e[41m" # Red
    B_GRN="\e[42m" # Green
    B_YLW="\e[43m" # Yellow
    B_BLU="\e[44m" # Blue
    B_PUR="\e[45m" # Purple
    B_CYN="\e[46m" # Cyan
    B_WHT="\e[47m" # White

    # BOLD BACKGROUND
    BB_BLK="\e[1;40m" # Black
    BB_RED="\e[1;41m" # Red
    BB_GRN="\e[1;42m" # Green
    BB_YLW="\e[1;43m" # Yellow
    BB_BLU="\e[1;44m" # Blue
    BB_PUR="\e[1;45m" # Purple
    BB_CYN="\e[1;46m" # Cyan
    BB_WHT="\e[1;47m" # White

    # COLOR OPTIONS
    NORMAL="\e[0m" # Text Reset
    BOLD="\e[1m" # Make Bold
    UNDERLINE="\e[4m" # Underline
    NOUNDER="\e[24m" # Remove Underline
    BLINK="\e[5m" # Make Blink
    NOBLINK="\e[25m" # NO Blink
    REVERSE="\e[50m" # Reverse
  fi
}

_setMessages_()
{
  if tput setaf 1 &>/dev/null; then
    GOODSTRING="$(tput bold)$(tput setaf 7)$(tput setab 10)[ OK ]$(tput sgr0)"
    BADSTRING="$(tput bold)$(tput setaf 8)$(tput setab 9)[FAIL]$(tput sgr0)"
    INFOSTRING="$(tput bold)$(tput setaf 7)$(tput setab 14)[INFO]$(tput sgr0)"
    DONESTRING="$(tput bold)$(tput setaf 7)$(tput setab 10)[DONE]$(tput sgr0)"
    MAKESTRING="$(tput bold)$(tput setaf 7)$(tput setab 13)[MAKE]$(tput sgr0)"
    WARNSTRING="$(tput bold)$(tput setaf 8)$(tput setab 11)[WARN]$(tput sgr0)"
  else
    GOODSTRING="\e[1m\e[1;37m\e[1;42m[ OK ]\e[0m"
    BADSTRING="\e[1m\e[1;30m\e[1;41m[FAIL]\e[0m "
    INFOSTRING="\e[1m\e[1;30m\e[1;46m[INFO]\e[0m"
    DONESTRING="\e[1m\e[1;37m\e[1;42m[DONE]\e[0m"
    MAKESTRING="\e[1m\e[1;37m\e[1;45m[MAKE]\e[0m"
    WARNSTRING="\e[1m\e[1;30m\e[1;43m[WARN]\e[0m"
  fi
}

##
## MAIN OUTPUT_MSG PRINTING FUNCTION
## EX: PMSG "INFO" "Test Message Info"
##
PMSG()
{
  if [[ "$LOGMSG" -ne 0 ]]; then
    if [ -z "${LOGFILE:-}" ]; then
      LOGFILE="$(pwd)/$(basename "$0").log"
    fi
    [ ! -d "$(dirname "${LOGFILE}")" ] && mkdir -p "$(dirname "${LOGFILE}")"
    [[ ! -f ${LOGFILE} ]] && touch "${LOGFILE}"

    # Don't use colors in logs
    if command -v gsed &>/dev/null; then
      local cleanmessage="$(echo "${2}" | gsed -E 's/(\x1b)?\[(([0-9]{1,2})(;[0-9]{1,3}){0,2})?[mGK]//g')"
    else
      local cleanmessage="$(echo "${2}" | sed -E 's/(\x1b)?\[(([0-9]{1,2})(;[0-9]{1,3}){0,2})?[mGK]//g')"
    fi

    echo -e "$(date +"%b %d %R:%S") $(printf "[%4s]" "${1}") [$(/bin/hostname)] ${2}" >>"${LOGFILE}"
  fi

  case $1 in

    GOOD)
      printf "${GOODSTRING} ${BGRN}%s${NC}\n" "$2"
      ;;

    BAD)
      printf "\n${BADSTRING} ${BRED}%s${NC}\n" "$2"
      _safeExit_ "1"
      ;;

    INFO)
      printf "${INFOSTRING} ${BCYN}%s${NC}\n" "$2"
      ;;

    WARN)
      printf "\n${WARNSTRING} ${BYLW}%s${NC}\n" "$2"
      ;;

    DONE)
      printf "\n${DONESTRING} ${BGRN}%s${NC}\n" "$2"
      ;;

    MAKE)
      printf "${MAKESTRING} ${BPUR}%s${NC}\n" "$2"
      ;;

    *)
      printf "${INFOSTRING} ${BWHT}%s${NC}\n" "$2"
      ;;

  esac
}

## Print a horizontal rule
## @param $1 default line break char. ie: -
ruleln()
{
  if [ "$#" -lt 2 ]; then
    COLS=$(tput cols)
  else
    COLS="$2"
  fi

  printf -v _hr "%*s" "${COLS}" && echo "${_hr// /${1--}}"
}

## Print horizontal ruler with message
## @param $1 message we are going to display
## @param $2 default line break char. ie: -
rulemsg()
{
  if [ "$#" -eq 0 ]; then
    echo "Usage: rulemsg MESSAGE [RULE_CHARACTER]"
    return 1
  fi

  # Store Cursor.
  # Fill line with ruler character ($2, default "-")
  # Reset cursor
  # move 10 cols right, print message

  tput sc # save cursor
  printf -v _hr "%*s" 80 && echo -n "${BPUR}" && echo -en ${_hr// /${2--}} && echo -en "\r\033[2C"
  tput rc

  echo -en "\r\033[10C" && echo -n "${BGRN} [ ${BBLU}$1${BGRN} ]" # 10 space in

  echo " " # now we break
  echo " "
}

#== usage functions ==#
usage()
{
  echo -e "${BCYN}"
  printf "Usage: "
                    head -${SCRIPT_HEADSIZE:-99} ${0} | grep -e "^#+" | sed -e "s/^#+[ ]*//g" -e "s/\${SCRIPT_NAME}/${SCRIPT_NAME}/g"
  echo -e "${NC}"
}

usagefull()
{
  echo -e "${BBLU}"
  printf " "
                head -${SCRIPT_HEADSIZE:-99} ${0} | grep -e "^#[%+-]" | sed -e "s/^#[%+-]//g" -e "s/\${SCRIPT_NAME}/${SCRIPT_NAME}/g"
  echo -e "${NC}"
}

version()
{
    grep '^# VERSION:' "$0"
    echo ""
    exit 0
}

# File Checks
## ------------------ ---------  ------   ----    ---     --      -
#   A series of functions which make checks against the filesystem.
#   For use in if/then statements.
#
#   Usage:
#      if is_file "file"; then
#         ...
#      fi
## ------------------ ---------  ------   ----    ---     --      -

is_exists()
                     {
  if [[ -e "$1" ]]; then
    return 0
  fi
  return 1
}

is_not_exists()
                         {
  if [[ ! -e "$1" ]]; then
    return 0
  fi
  return 1
}

is_file()
                   {
  if [[ -f "$1" ]]; then
    return 0
  fi
  return 1
}

is_not_file()
                       {
  if [[ ! -f "$1" ]]; then
    return 0
  fi
  return 1
}

is_dir()
                  {
  if [[ -d "$1" ]]; then
    return 0
  fi
  return 1
}

is_not_dir()
                      {
  if [[ ! -d "$1" ]]; then
    return 0
  fi
  return 1
}

is_symlink()
                      {
  if [[ -L "$1" ]]; then
    return 0
  fi
  return 1
}

is_not_symlink()
                          {
  if [[ ! -L "$1" ]]; then
    return 0
  fi
  return 1
}

is_empty()
                    {
  if [[ -z "$1" ]]; then
    return 0
  fi
  return 1
}

is_not_empty()
                        {
  if [[ -n "$1" ]]; then
    return 0
  fi
  return 1
}

########
######## FUNCTIONS
########

function packItUp
{
    PMSG "INFO" "Compressing Files in: $1"
    tmpfile=$(mktemp /tmp/SortedImages.zip)
    # zip -r "${ZIP}/images.zip" "$1"
    zip -r "$tmpfile" "$1"
    PMSG "GOOD" "Archive Created!"
    mv "$tmpfile" "${TARGET_DIR}"
    #rm "$tmpfile"
    #ls -l "$1" | grep .zip
    mfs=$(du --apparent-size --block-size=1  "${TARGET_DIR}/SortedImages.zip" | awk '{ print $1}')
    PMSG "GOOD" "Zip Archive Size: ${mfs}"
}

function removeDupes
{
    if ! command -v fdupes &>/dev/null; then
        die "Install fdupes command to remove duplicate files"
    else
        PMSG "INFO" "Searching Files in: $1"
        BEFORE=$(ls "$1" | wc -l)
        fdupes -qdN -r "$1"
        AFTER=$(ls "$1" | wc -l)
        PMSG "INFO" "BEFORE: ${BEFORE} Files"
        PMSG "INFO" " AFTER: ${AFTER} Files"
    fi
}

renameFile()
{
    FILE=$1
    randomString=$(openssl rand -base64 6)
    FileName=$(basename -- "$FILE")
    Extension="${FileName##*.}"
    FName="${FileName%.*}"
    local newName="${FName}_${randomString}.${Extension}"
}

imgLogic()
{
	imgFile="$1"
	saveDir="$2"
	
	if [ -f $1 ]; then

	    ImgBaseName=$(basename "$1")
			
	    if [ -f "$2/${ImgBaseName}" ]; then
				PMSG "WARN" "POTENTIALLY ALREADY PRESENT IMAGE"
	      ## Check Filesize
	      filesize_one=$($DU -b "$2/${ImgBaseName}" | cut -f1)
	      filesize_two=$($DU -b "$1" | cut -f1)

	      if [ "$filesize_one" -eq "$filesize_two" ]; then
	          PMSG "WARN" "Skipping $1. Already Moved"
	      else
	          PMSG "INFO" "Renaming $1 to avoid conflict"

	          # randomString=$(openssl rand -base64 6)
	          # imgFileName=$(basename -- "$imgFile")
	          # imgExtension="${imgFileName##*.}"
	          # imgName="${imgFileName%.*}"
	          # newName="${imgName}_${randomString}.${imgExtension}"
	          newName=$(renameFile "$1")
	          mv "$1" "$2/${newName}"
	          DFD=$((DFD + 1))
	      fi
	    else
	      # We have found a valid image file
	      PMSG "INFO" "Sorting ${ImgBaseName}"
	      mv $imgFile "$2/${ImgBaseName}"
	      DFD=$((DFD + 1))
	    fi
	fi
}

sortPathToDir()
{
  ## Sort all Images
  if [[ "$EXT_FLAG" -eq 0 ]]; then
      for img in $1.{png,jpg,jpeg,eps,svg,ai,psd}; do
          imgLogic $img $TARGET_DIR
      done
  else
      ## Sort Images into Raster / Vector Subfolders
      mkdir -p "${TARGET_DIR}/RASTERS"
      for img in $1.{jpg,jpeg,png,psd}; do
          imgLogic $img "${TARGET_DIR}/RASTERS"
      done

      mkdir -p "${TARGET_DIR}/VECTORS"
      for img in $1.{ai,eps,svg}; do
          imgLogic $img "${TARGET_DIR}/VECTORS"
      done
  fi

  ## Clean Out Any Bullshit Files
  for badFile in $1.{txt,pdf,doc}; do
		if [ -f $badFile ]; then
      PMSG "INFO" "Removing Garbage File: ${badFile}"
      rm "${badFile}"
		fi
  done
}

function mergeLibraries
{
    PMSG "INFO" "Rsyncing Directories"

    RTarget="$TARGET_DIR"

    rsync -abvuP "$RTarget" "$RDest"

    PMSG "GOOD" "Finished Syncing!"
}

function filterIcons
{
    # Run Through Target Dir and move icons into subfolder
    PMSG "INFO" "Sorting Icons into Subfolder"

    filterCount=0

    # Linux Only
    # filesize=$(stat -c%s "$FILE")

    # MacOS
    # filesize=$(stat -f%z "$FILE")

    # POSIX
    #filesize=$(du -b "$FILE" | cut -f1)

    if [[ "$EXT_FLAG" -eq 0 ]]; then
        ICONDIR="${TARGET_DIR}/ICONS_PNG"
        ICONVECTDIR="${TARGET_DIR}/ICONS"
    else
        ICONVECTDIR="${TARGET_DIR}/VECTORS/ICONS"
        ICONDIR="${TARGET_DIR}/RASTERS/ICONS"
    fi

    mkdir -p "${ICONDIR}"
    mkdir -p "${ICONVECTDIR}"

    for FILE in "${TARGET_DIR}"/*.{svg,eps}; do
        filesize=$($DU -b "$FILE" | cut -f1)
        if [ "$filesize" -lt 80000 ]; then
            PMSG "INFO" "Moving Icon: $FILE"
            mv "$FILE" "${ICONVECTDIR}"
            filterCount=$((filterCount + 1))
        fi
    done

    for FILE in "${TARGET_DIR}"/*.png; do
        filesize=$($DU -b "$FILE" | cut -f1)
        if [ "$filesize" -lt 100000 ]; then
            PMSG "INFO" "Moving PNG Icon: $FILE"
            mv "$FILE" "${ICONDIR}"
            filterCount=$((filterCount + 1))
        fi
    done

    PMSG "GOOD" "Sorted ${filterCount} Icon Files"
}

sortImages()
{
    mkdir -p $TARGET_DIR
		PMSG "INFO" " PROCESSING ${IMGPATH} & SAVING TO ${TARGET_DIR} "

    ## Cleanup Filenames first
    if ! command -v rename &>/dev/null; then
        die "Install rename command to correct capitalized extension errors"
    else
        PMSG "INFO" "lowercasing extensions SVG to svg etc..."
        rename -n 's/\.([^.]+)$/.\L$1/' "${IMGPATH}"
    fi

    if ! command -v detox &>/dev/null; then
        die "Install detox command to correct capitalized extension errors"
    else
        PMSG "INFO" "cleaning up filenames to remove garbage chars and whitespace etc."
        detox -r -v "${IMGPATH}"
    fi

    # PMSG "INFO" "removing whitespace from all filenames"

    # find "$IMGPATH" -depth -name '* *' |
    #     while IFS= read -r f; do mv -i "$f" "$(dirname "$f")/$(basename "$f" | tr ' ' _)"; done

    PMSG "GOOD" "Preliminary Work Completed. Processing Starting!"

    DFD=0
    PMSG "INFO" "Merging all |png, jpg, svg, ai| files"

    sortPathToDir "${IMGPATH}/*"
    sortPathToDir "${IMGPATH}/**/*"
    sortPathToDir "${IMGPATH}/**/**/*"
    sortPathToDir "${IMGPATH}/**/**/**/*"

    PMSG "GOOD" "Processed ${DFD} Images"

		if is_dir "${IMGPATH}"; then
			PMSG "INFO" "Cleaning Empty Directories from ${IMGPATH}"
			rm -r "${IMGPATH}"
		fi
		# clearEmptyDirs "${IMGPATH}"
		
}

clearEmptyDirs(){
	PMSG "INFO" "Cleaning Empty Directories from ${1}"

  find $1 -empty -type d -delete
  find $1 -type d -exec rmdir -v "{}" \;
	#find "$IMGPATH" -type d -exec rmdir {} + 2>/dev/null
	find $1 -type f -empty -print0 | xargs -0 -I {} /bin/rm "{}"
	
	for dir in $1; do
	   files=("$dir"/*)
	   [[ ${files[@]} ]] || rm -r "$dir"
	done
	
	PMSG "GOOD" "Done Cleaning!"
}


DU=/usr/local/bin/gdu
#TARGET_DIR="${HOME}/Pictures"
TARGET_DIR=""
PACK_FLAG=0
SORT_FLAG=0
DEDUPE_FLAG=0
EXT_FLAG=0
ICON_FLAG=0
MERG_FLAG=0
PARAMS=""

# SCRIPT FUNCTIONALITY
## ------------------ ---------  ------   ----    ---     --      -

_mainAction_() {

	#DICE=$(awk 'BEGIN {srand(); print int(6 * rand()) + 1}')
	#PMSG "DONE" "${BCYN}You Rolled a ${BPUR}${DICE}${NORMAL}"

	#echo -e "\n"
	
	if [[ -z "$TARGET_DIR" ]]; then
			PMSG "BAD" "--target directory not set! Cannot continue!"
	fi
	
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
	
  if [[ "$MERG_FLAG" -eq 1 ]]; then
      PMSG "INFO" "Starting Directory Merg"
      mergeLibraries
  fi

  PMSG "GOOD" "Script Finished!"
}

die() {
_safeExit_
}

_parseOptions_() {

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
				MERG_FLAG=1
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
	_parseOptions_ "-h"
else
	_parseOptions_ "$@"
	# Init main Logic
	_mainAction_
fi

# Exit cleanly
_safeExit_