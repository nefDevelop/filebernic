#!/bin/bash

# Script to compress 'filebernic' and 'glyph' directories into a single .muxapp file.

# Define the directories to be compressed
DIR1="filebernic"
# DIR2="glyph"

# Check if both directories exist
if [ ! -d "$DIR1" ]; then
  echo "Error: Directory '$DIR1' not found."
  exit 1
fi

# if [ ! -d "$DIR2" ]; then
  # echo "Error: Directory '$DIR2' not found."
  # exit 1
# fi

ZIP_FILENAME="${DIR1}.zip" # Output zip will be named after the main app
MUXAPP_FILENAME="${DIR1}.muxapp"

echo "Compressing directories '$DIR1' to '$ZIP_FILENAME'..."
# -r: recurse into directories
# -q: quiet operation
# -x "*.DS_Store" -x "__MACOSX" -x ".git*" : Exclude common unwanted files/directories
# Zip both directories at the root of the archive
zip -rq "$ZIP_FILENAME" "$DIR1" -x "*.DS_Store" -x "__MACOSX" -x ".git*" -x "$DIR1/data/*"

if [ $? -eq 0 ]; then
  echo "Compression successful. Renaming '$ZIP_FILENAME' to '$MUXAPP_FILENAME'..."
  mv "$ZIP_FILENAME" "$MUXAPP_FILENAME"
  if [ $? -eq 0 ]; then
    echo "Successfully created '$MUXAPP_FILENAME'."
    echo "You can now transfer '$MUXAPP_FILENAME' to your muOS device."
  else
    echo "Error: Failed to rename '$ZIP_FILENAME' to '$MUXAPP_FILENAME'."
    exit 1
  fi
else
  echo "Error: Failed to compress directories '$DIR1'."
  exit 1
fi
