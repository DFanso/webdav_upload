# WebDAV File Downloader and Uploader Script

### SLT Life Hacks

This script downloads a file from a specified URL, splits it into 500MB parts using 7-Zip, creates a folder on a WebDAV server, and uploads the split parts to that folder.

## Prerequisites

Ensure you have the following installed on your Ubuntu server:

1. **7-Zip**: 
   ```bash
   sudo apt-get update
   sudo apt-get install p7zip-full
   ```

2. **cURL**: 
   ```bash
   sudo apt-get install curl
   ```

3. **jq**: 
   ```bash
   sudo apt-get install jq
   ```

## Usage

1. **Download the Script**

   Save the following script as `webdav_upload.sh`:

   ```bash
   #!/bin/bash

   # Variables (modify these)
   WEB_DAV_URL="https://your-webdav-server.com/remote.php/webdav"
   WEB_DAV_USERNAME="your-username"
   WEB_DAV_PASSWORD="your-password"

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
   ```

2. **Make the Script Executable**
   
   ```bash
   chmod +x webdav_upload.sh
   ```

3. **Run the Script**

   Execute the script and follow the prompt to enter the download URL:

   ```bash
   ./webdav_upload.sh
   ```

   You will be prompted to enter the download URL. The script will then download the file, split it, create a folder on the WebDAV server, and upload the split parts.

## Configuration

Modify the following variables in the script to match your WebDAV server details:

- `WEB_DAV_URL`: The URL of your WebDAV server.
- `WEB_DAV_USERNAME`: Your WebDAV username.
- `WEB_DAV_PASSWORD`: Your WebDAV password.

## Notes

- Ensure that the WebDAV server credentials are kept secure and not hardcoded in publicly accessible scripts.
- This script assumes that the WebDAV server and required packages are properly configured and accessible from the server where the script is run.
