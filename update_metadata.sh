#!/bin/bash
# Script to update the token metadata for the Solotto token
# Usage: ./update_metadata.sh <TOKEN_ADDRESS>

if [ -z "$1" ]; then
  echo "Error: Token address is required"
  echo "Usage: ./update_metadata.sh <TOKEN_ADDRESS>"
  exit 1
fi

TOKEN_ADDRESS=$1

# Set the metadata URL
METADATA_URL="https://raw.githubusercontent.com/edfarialand/solotto/master/SOLOTTO_METADATA.json"

echo "Updating metadata for token: $TOKEN_ADDRESS"
echo "Using metadata URL: $METADATA_URL"

# Update the token metadata
echo "Updating token metadata..."
spl-token update-metadata $TOKEN_ADDRESS "Solotto Beta" "SLTO" "$METADATA_URL" --program-2022

echo "Token metadata updated successfully!"
echo "New name: Solotto Beta"
echo "Symbol: SLTO"
echo "Metadata URL: $METADATA_URL"

# Display token details
echo "Updated token details:"
spl-token display $TOKEN_ADDRESS --program-2022