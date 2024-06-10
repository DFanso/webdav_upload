#!/bin/bash

# Variables (modify these)
WEB_DAV_URL=""
WEB_DAV_USERNAME=""
WEB_DAV_PASSWORD=""

# Function to sanitize file names
sanitize() {
  echo "$1" | tr -cd '[:alnum:]._-'
}

# Prompt the user to enter the download URL
read -p "Please enter the download URL: " DOWNLOAD_URL

# Check if the download URL is provided
if [ -z "$DOWNLOAD_URL" ]; then
  echo "No download URL provided. Exiting."
  exit 1
fi

# Extract file name from URL and sanitize it
FILE_NAME=$(basename "$DOWNLOAD_URL")
FILE_NAME_WITHOUT_QUERY="${FILE_NAME%%\?*}"
SANITIZED_FILE_NAME=$(sanitize "$FILE_NAME_WITHOUT_QUERY")

# Download the file
wget -O "$SANITIZED_FILE_NAME" "$DOWNLOAD_URL"

# Check if download was successful
if [ $? -ne 0 ]; then
  echo "Failed to download the file."
  exit 1
fi

# Split the file into 500MB parts
7z a -v500m "${SANITIZED_FILE_NAME}.7z" "$SANITIZED_FILE_NAME"

# Create a folder on the WebDAV server
FOLDER_NAME="${SANITIZED_FILE_NAME%.*}"
ENCODED_FOLDER_NAME=$(echo -n "$FOLDER_NAME" | jq -sRr @uri)
curl -u "$WEB_DAV_USERNAME:$WEB_DAV_PASSWORD" -X MKCOL "$WEB_DAV_URL/$ENCODED_FOLDER_NAME/"

# Check if folder creation was successful
if [ $? -ne 0 ]; then
  echo "Failed to create folder on WebDAV server."
  exit 1
fi

# Upload the split parts to the WebDAV server
for PART in "${SANITIZED_FILE_NAME}.7z".*; do
  ENCODED_PART_NAME=$(echo -n "$PART" | jq -sRr @uri)
  curl -u "$WEB_DAV_USERNAME:$WEB_DAV_PASSWORD" -T "$PART" "$WEB_DAV_URL/$ENCODED_FOLDER_NAME/$ENCODED_PART_NAME"
  
  # Check if upload was successful
  if [ $? -ne 0 ]; then
    echo "Failed to upload $PART to WebDAV server."
    exit 1
  fi
done

# Clean up
rm "$SANITIZED_FILE_NAME" "${SANITIZED_FILE_NAME}.7z".*

echo "File downloaded, split, and uploaded successfully."
