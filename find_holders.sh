#!/bin/bash
# Script to find all holders of a specific token and their balances
# Usage: ./find_holders.sh <TOKEN_ADDRESS> [MIN_BALANCE]

if [ -z "$1" ]; then
  echo "Error: Token address is required"
  echo "Usage: ./find_holders.sh <TOKEN_ADDRESS> [MIN_BALANCE]"
  exit 1
fi

TOKEN_ADDRESS=$1
MIN_BALANCE=${2:-1}  # Default to 1 if not specified

echo "Finding holders for token: $TOKEN_ADDRESS"
echo "Minimum balance: $MIN_BALANCE"

# Temporary files
ACCOUNTS_FILE=$(mktemp)
HOLDERS_FILE=$(mktemp)

# Get all token accounts for this mint
echo "Fetching all accounts for this token (this may take a while)..."
solana spl-token accounts $TOKEN_ADDRESS -v --output json > $ACCOUNTS_FILE

# Check if any accounts were found
if [ ! -s "$ACCOUNTS_FILE" ]; then
  echo "No accounts found for token $TOKEN_ADDRESS"
  rm $ACCOUNTS_FILE
  exit 0
fi

# Extract account addresses and balances, filter by minimum balance
echo "Processing account data..."
cat $ACCOUNTS_FILE | jq -r '.[] | select(.tokenAmount.amount | tonumber >= '$MIN_BALANCE') | [.address, .owner, .tokenAmount.amount] | @csv' > $HOLDERS_FILE

# Count total holders
TOTAL_HOLDERS=$(wc -l < $HOLDERS_FILE)
echo "Found $TOTAL_HOLDERS token holders with at least $MIN_BALANCE tokens"

# Display holders sorted by balance (highest first)
echo "Top 20 holders by balance:"
echo "ADDRESS,OWNER,BALANCE"
sort -t, -k3,3nr $HOLDERS_FILE | head -20

# Clean up temporary files
rm $ACCOUNTS_FILE $HOLDERS_FILE

# Create a random selection function for lottery
echo ""
echo "To select 4 random holders for lottery, run:"
echo './select_lottery_winner.sh '$TOKEN_ADDRESS
echo ""