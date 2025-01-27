#!/usr/bin/env sh

# Variables
TAR_URL="https://event.cwi.nl/da/job/imdb.tgz"
DEST_DIR="./dataset"
TAR_FILE="$DEST_DIR/imdb.tgz"

# Check if the destination directory exists
if [ -d "$DEST_DIR" ]; then
  echo "Aborting: $DEST_DIR already exists. Run 'rm -rf $DEST_DIR' to redownload."
  exit 1
else
  # Create the destination directory
  mkdir -p "$DEST_DIR"
  echo "Created directory: $DEST_DIR"
fi

# Use wget to download the tar file and pipe the output to stdout
echo "Downloading $TAR_URL..."
wget -O "$TAR_FILE" "$TAR_URL"
if [ $? -ne 0 ]; then
  echo "Error: Failed to download $TAR_URL."
  exit 1
fi

# Extract the tar file
echo "Extracting $TAR_FILE into $DEST_DIR..."
tar -xvzf "$TAR_FILE" -C "$DEST_DIR"
if [ $? -ne 0 ]; then
  echo "Error: Failed to extract $TAR_FILE."
  exit 1
fi

echo "Extraction completed."
