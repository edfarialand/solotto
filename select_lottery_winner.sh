#!/bin/bash
# Script to select a lottery winner from Solotto token holders
# Usage: ./select_lottery_winner.sh <TOKEN_ADDRESS>

if [ -z "$1" ]; then
  echo "Error: Token address is required"
  echo "Usage: ./select_lottery_winner.sh <TOKEN_ADDRESS>"
  exit 1
fi

TOKEN_ADDRESS=$1

echo "Running weekly Solotto lottery for token: $TOKEN_ADDRESS"

# Temporary files
ACCOUNTS_FILE=$(mktemp)
HOLDERS_FILE=$(mktemp)
SELECTED_FILE=$(mktemp)

# Get all token accounts for this mint
echo "Fetching all token holders (this may take a while)..."
solana spl-token accounts $TOKEN_ADDRESS -v --output json > $ACCOUNTS_FILE

# Check if any accounts were found
if [ ! -s "$ACCOUNTS_FILE" ]; then
  echo "No accounts found for token $TOKEN_ADDRESS"
  rm $ACCOUNTS_FILE
  exit 0
fi

# Extract account addresses and balances, filter by holders with >0 balance
echo "Processing account data..."
cat $ACCOUNTS_FILE | jq -r '.[] | select(.tokenAmount.amount | tonumber > 0) | [.owner, .tokenAmount.amount] | @csv' > $HOLDERS_FILE

# Count total eligible holders
TOTAL_HOLDERS=$(wc -l < $HOLDERS_FILE)
echo "Found $TOTAL_HOLDERS eligible token holders"

if [ $TOTAL_HOLDERS -lt 4 ]; then
  echo "Not enough holders to run lottery (minimum 4 required)"
  rm $ACCOUNTS_FILE $HOLDERS_FILE
  exit 0
fi

# Select 4 random holders
echo "Randomly selecting 4 holders..."
sort -R $HOLDERS_FILE | head -4 > $SELECTED_FILE

# Find the holder with highest balance among the 4 selected
echo "Determining winner based on highest balance..."
WINNER=$(sort -t, -k2,2nr $SELECTED_FILE | head -1)
WINNER_ADDR=$(echo $WINNER | cut -d, -f1 | tr -d '"')
WINNER_BALANCE=$(echo $WINNER | cut -d, -f2 | tr -d '"')

echo "🎉 LOTTERY WINNER: $WINNER_ADDR"
echo "Winner's token balance: $WINNER_BALANCE SLTO"

# Display all selected finalists for transparency
echo ""
echo "All 4 randomly selected finalists:"
cat $SELECTED_FILE | while IFS=, read -r addr balance || [ -n "$addr" ]; do
  addr=$(echo $addr | tr -d '"')
  balance=$(echo $balance | tr -d '"')
  if [ "$addr" = "$WINNER_ADDR" ]; then
    echo "🏆 $addr - $balance SLTO (WINNER)"
  else
    echo "👤 $addr - $balance SLTO"
  fi
done

# Withdraw withheld tokens from transfer fees
echo ""
echo "Collecting withheld transfer fees..."
OWNER_ACCOUNT=$(solana address)

# Get the current withheld amount before withdrawing
WITHHELD_INFO=$(spl-token display $TOKEN_ADDRESS --program-2022)
echo "Current token info:"
echo "$WITHHELD_INFO"

echo ""
echo "Automatically withdrawing fees and sending to the winner..."

# Create a temporary account to hold the collected fees
echo "Creating temporary account for fee collection..."
TEMP_ACCOUNT=$(spl-token create-account $TOKEN_ADDRESS --program-2022 | grep "Creating" | awk '{print $3}')
echo "Temporary account created: $TEMP_ACCOUNT"

# Withdraw the withheld tokens to the temporary account
echo "Withdrawing withheld tokens from transfer fees..."
WITHDRAW_OUTPUT=$(spl-token withdraw-withheld-tokens $TOKEN_ADDRESS --withheld-token-account $TEMP_ACCOUNT --program-2022)
echo "$WITHDRAW_OUTPUT"

# Get the amount withdrawn
AMOUNT=$(echo "$WITHDRAW_OUTPUT" | grep -oP '(\d+\.\d+|\d+)' | head -1)
echo "Amount collected from fees: $AMOUNT SLTO"

if [[ -z "$AMOUNT" || "$AMOUNT" == "0" || "$AMOUNT" == "0.0" ]]; then
  echo "No fees collected yet. Nothing to transfer."
else
  # Transfer all tokens from temporary account to the winner
  echo "🎉 Transferring $AMOUNT SLTO to lottery winner: $WINNER_ADDR"
  spl-token transfer --from $TEMP_ACCOUNT $TOKEN_ADDRESS $AMOUNT $WINNER_ADDR --program-2022 --fund-recipient
  echo "Transfer complete! Winner has received their prize directly."
  
  # Close the temporary account
  echo "Cleaning up temporary account..."
  spl-token close --address $TEMP_ACCOUNT --program-2022
fi

# Save winner information to a file for reference
echo "Saving winner information for this week..."
echo "$WINNER_ADDR" > /home/ed/solotto/current_winner.txt
echo "$(date +"%Y-%m-%d")" >> /home/ed/solotto/current_winner.txt

# Clean up temporary files
rm $ACCOUNTS_FILE $HOLDERS_FILE $SELECTED_FILE