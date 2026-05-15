
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
    GOODSTRING="$(tput bold)$(tput setaf 7)$(tput setab 12)[ OK ]$(tput sgr0)"
    BADSTRING="$(tput bold)$(tput setaf 8)$(tput setab 9)[FAIL]$(tput sgr0)"
    INFOSTRING="$(tput bold)$(tput setaf 7)$(tput setab 14)[INFO]$(tput sgr0)"
    DONESTRING="$(tput bold)$(tput setaf 7)$(tput setab 10)[DONE]$(tput sgr0)"
    MAKESTRING="$(tput bold)$(tput setaf 7)$(tput setab 13)[MAKE]$(tput sgr0)"
    WARNSTRING="$(tput bold)$(tput setaf 8)$(tput setab 11)[WARN]$(tput sgr0)"
  else
    GOODSTRING="\e[1m\e[1;37m\e[1;44m[ OK ]\e[0m"
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
      printf "\n${GOODSTRING} ${BBLU}%s${NC}\n" "$2"
      ;;

    BAD)
      printf "\n${BADSTRING} ${BRED}%s${NC}\n" "$2"
      _safeExit_ "1"
      ;;

    INFO)
      printf "\n${INFOSTRING} ${BCYN}%s${NC}\n" "$2"
      ;;

    WARN)
      printf "\n${WARNSTRING} ${BYLW}%s${NC}\n" "$2"
      ;;

    DONE)
      printf "\n${DONESTRING} ${BGRN}%s${NC}\n" "$2"
      ;;

    MAKE)
      printf "\n${MAKESTRING} ${BPUR}%s${NC}\n" "$2"
      ;;

    *)
      printf "\n${INFOSTRING} ${BWHT}%s${NC}\n" "$2"
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
