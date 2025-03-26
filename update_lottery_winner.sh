#!/bin/bash
# Script to update the lottery winner for Solotto token
# Usage: ./update_lottery_winner.sh <TOKEN_ADDRESS>
#
# This script selects a new lottery winner and updates the configuration.
# It should be run once per week to select a new winner.

if [ -z "$1" ]; then
  echo "Error: Token address is required"
  echo "Usage: ./update_lottery_winner.sh <TOKEN_ADDRESS>"
  exit 1
fi

TOKEN_ADDRESS=$1

echo "Running Solotto weekly lottery for token: $TOKEN_ADDRESS"

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

# Create our authority account for the token
AUTHORITY_ACCOUNT=$(solana address)

# Transfer any accumulated fees from the authority account
# First withdraw withheld tokens from transfer fees to the authority
echo ""
echo "Withdrawing accumulated transfer fees..."
# We withdraw to the default account of the authority
spl-token withdraw-withheld-tokens $TOKEN_ADDRESS --program-2022

# Then transfer all tokens from the authority to the winner
echo "Transferring accumulated fees to winner..."
CURRENT_BALANCE=$(spl-token balance $TOKEN_ADDRESS --program-2022)
if [[ $CURRENT_BALANCE -gt 0 ]]; then
  spl-token transfer $TOKEN_ADDRESS $CURRENT_BALANCE $WINNER_ADDR --fund-recipient --program-2022
  echo "Successfully transferred $CURRENT_BALANCE SLTO to winner: $WINNER_ADDR"
else
  echo "No accumulated fees yet."
fi

# Save the current winner to a file for reference
echo "Updating current winner information..."
mkdir -p /home/ed/solotto/lottery_data
echo "$WINNER_ADDR" > /home/ed/solotto/lottery_data/current_winner.txt
echo "$(date +"%Y-%m-%d")" >> /home/ed/solotto/lottery_data/current_winner.txt

# Update the history of winners
echo "$WINNER_ADDR,$(date +"%Y-%m-%d"),$WINNER_BALANCE,$CURRENT_BALANCE" >> /home/ed/solotto/lottery_data/winner_history.csv

echo ""
echo "🏆 New lottery winner has been selected and updated: $WINNER_ADDR"
echo "All accumulated fees have been transferred to the winner"
echo "Next lottery drawing will select a new winner"

# Clean up temporary files
rm $ACCOUNTS_FILE $HOLDERS_FILE $SELECTED_FILE