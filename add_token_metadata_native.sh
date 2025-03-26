#!/bin/bash
# Script to add metadata to the Solotto token using native Solana tools
# Usage: ./add_token_metadata_native.sh <TOKEN_ADDRESS>

if [ -z "$1" ]; then
  echo "Error: Token address is required"
  echo "Usage: ./add_token_metadata_native.sh <TOKEN_ADDRESS>"
  exit 1
fi

TOKEN_ADDRESS=$1
METADATA_URI="https://raw.githubusercontent.com/edfarialand/solotto/master/SOLOTTO_METADATA.json"

echo "Adding metadata to token: $TOKEN_ADDRESS"

# Update the token metadata using the spl-token command
echo "Updating token metadata..."
spl-token update-metadata $TOKEN_ADDRESS "Solotto Beta" "SLTO" "$METADATA_URI" --program-2022

echo "✅ Token metadata updated successfully!"
echo "Token: $TOKEN_ADDRESS"
echo "Name: Solotto Beta"
echo "Symbol: SLTO"
echo "Metadata URI: $METADATA_URI"

echo "You can view your token on explorers like Solscan and Solana Explorer."
echo "- Solscan: https://solscan.io/token/\${TOKEN_ADDRESS}"
echo "- Solana Explorer: https://explorer.solana.com/address/\${TOKEN_ADDRESS}"