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
	PMSG "INFO" "${imgFile} ${saveDir}"
	
	if [ -f $imgFile ] && [[ $imgFile != .* ]]; then

	    ImgBaseName=$(basename "${imgFile}")

	    if [ -f "${TARGET_DIR}/${ImgBaseName}" ]; then
				PMSG "WARN" "POTENTIALLY ARLEADY PRESENT IMAGE"
	      ## Check Filesize
	      filesize_one=$(/usr/local/bin/gdu -b "${TARGET_DIR}/${ImgBaseName}" | cut -f1)
	      filesize_two=$(/usr/local/bin/gdu -b "${imgFile}" | cut -f1)

	      if [ "${filesize_one}" -eq "${filesize_two}" ]; then
	          PMSG "WARN" "Skipping ${imgFile}. Already Moved"
	      else
	          PMSG "INFO" "Renaming ${imgFile} to avoid conflict"

	          # randomString=$(openssl rand -base64 6)
	          # imgFileName=$(basename -- "$imgFile")
	          # imgExtension="${imgFileName##*.}"
	          # imgName="${imgFileName%.*}"
	          # newName="${imgName}_${randomString}.${imgExtension}"
	          newName=$(renameFile "${imgFile}")
	          mv "${imgFile}" "${saveDir}/${newName}"
	          DFD=$((DFD + 1))
	      fi
	    else
	      # We have found a valid image file
	      PMSG "INFO" "Sorting ${ImgBaseName}"
	      mv "${imgFile}" "${saveDir}/${ImgBaseName}"
	      DFD=$((DFD + 1))
	    fi
	fi
}

sortPathToDir()
{
  ## Sort all Images
  if [[ $EXT_FLAG -eq 0 ]]; then
      for img in $1.{png,jpg,jpeg,eps,svg,ai,psd}; do
          imgLogic $img "${TARGET_DIR}"
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
		if [ -f "${badFile}" ]; then
      PMSG "INFO" "Removing Garbage File: ${badFile}"
      rm "${badFile}"
		fi
  done
}

function mergeLibraries
{
	D1Name=$(basename "${TARGET_DIR}")
	D2Name=$(basename "${RDest}")
  PMSG "INFO" "RSYNC | ${D1Name} -TO- ${D2Name}"

  rsync -abvuP "${TARGET_DIR}" "${RDest}"

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
        filesize=$(/usr/local/bin/gdu -b "${FILE}" | cut -f1)
        if [ "$filesize" -lt 80000 ]; then
            PMSG "INFO" "Moving Icon: ${FILE}"
            mv "$FILE" "${ICONVECTDIR}"
            filterCount=$((filterCount + 1))
        fi
    done

    for FILE in "${TARGET_DIR}"/*.png; do
        filesize=$(/usr/local/bin/gdu -b "${FILE}" | cut -f1)
        if [ "$filesize" -lt 100000 ]; then
            PMSG "INFO" "Moving PNG Icon: ${FILE}"
            mv "${FILE}" "${ICONDIR}"
            filterCount=$((filterCount + 1))
        fi
    done

    PMSG "GOOD" "Sorted ${filterCount} Icon Files"
}

sortImages()
{
    mkdir -p "${TARGET_DIR}"
		PMSG "INFO" " TARGETING | ${TARGET_DIR} "
		PMSG "INFO" " IMGPATH   | ${IMGPATH} "

    ## Cleanup Filenames first
    if ! command -v rename &>/dev/null; then
        die "Install rename command to correct capitalized extension errors"
    else
        PMSG "INFO" "Lowercase ALL Extensions (SVG to svg) etc..."
        rename -n 's/\.([^.]+)$/.\L$1/' "${IMGPATH}"
    fi

    if ! command -v detox &>/dev/null; then
        die "Install detox command to correct capitalized extension errors"
    else
        PMSG "INFO" "Running 'detox' command to cleanup filenames"
        detox -r -v "${IMGPATH}"
    fi

    # PMSG "INFO" "removing whitespace from all filenames"

    # find "$IMGPATH" -depth -name '* *' |
    #     while IFS= read -r f; do mv -i "$f" "$(dirname "$f")/$(basename "$f" | tr ' ' _)"; done

    PMSG "GOOD" "Preliminary Work Completed! Processing Starting!"

    DFD=0
    PMSG "INFO" "Merging all |png, jpg, svg, ai| files"

    sortPathToDir "${IMGPATH}/*"
    sortPathToDir "${IMGPATH}/**/*"
    sortPathToDir "${IMGPATH}/**/**/*"
    sortPathToDir "${IMGPATH}/**/**/**/*"

    PMSG "GOOD" "Processed ${DFD} Images"

    PMSG "INFO" "Cleaning Empty Directories"
    find "${IMGPATH}/" -empty -type d -delete
}