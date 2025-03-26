#!/bin/bash
# Script to distribute Solotto tokens to a list of wallets from a CSV file
# Usage: ./distribute_to_csv.sh <CSV_FILE> [AMOUNT_PER_WALLET]

# Check if CSV file is provided
if [ -z "$1" ]; then
  echo "Error: CSV file path is required"
  echo "Usage: ./distribute_to_csv.sh <CSV_FILE> [AMOUNT_PER_WALLET]"
  exit 1
fi

CSV_FILE=$1
TOKEN_ADDRESS="4LjgzZFw7prpEGiHWGHLPvowUHZ3oQgWkwQxABowiZRM"  # Solotto token address
TOKEN_AMOUNT=${2:-1000}  # Default to 1000 if not specified

# Check if CSV file exists
if [ ! -f "$CSV_FILE" ]; then
  echo "Error: CSV file not found at $CSV_FILE"
  exit 1
fi

# Use the minting wallet for distribution
CONFIGURED_WALLET="4cbgRgFa4QbtaLDuLgvyHunswCTwXxW63zv5jMho6cGq"
echo "Using minting wallet: $CONFIGURED_WALLET"

# Show token info before distribution
echo "Current token information:"
spl-token display $TOKEN_ADDRESS --program-2022

# Check current supply
SUPPLY=$(spl-token supply $TOKEN_ADDRESS --program-2022)
echo "Current token supply: $SUPPLY"

# Get total number of wallets in CSV (ignoring empty lines and duplicates)
TOTAL_WALLETS=$(sort "$CSV_FILE" | uniq | grep -v "^$" | wc -l)
echo "Total number of unique wallets to receive tokens: $TOTAL_WALLETS"
TOTAL_TOKENS=$((TOTAL_WALLETS * TOKEN_AMOUNT))
echo "Total tokens to be distributed: $TOTAL_TOKENS SLTO"

# Skipping confirmation for automation
echo "⚠️  WARNING: Distributing $TOKEN_AMOUNT SLTO tokens to $TOTAL_WALLETS wallets ⚠️"
echo "Proceeding with distribution automatically..."

# Process each wallet in the CSV file
echo "Starting token distribution..."
SUCCESS_COUNT=0
FAILED_COUNT=0

# Create a log file for the distribution
LOG_FILE="distribution_$(date +%Y%m%d_%H%M%S).log"
echo "Distribution Log - $(date)" > $LOG_FILE
echo "Token: $TOKEN_ADDRESS" >> $LOG_FILE
echo "Amount per wallet: $TOKEN_AMOUNT SLTO" >> $LOG_FILE
echo "--------------------------------" >> $LOG_FILE

# Create a temporary file with unique non-empty wallet addresses
TEMP_WALLETS=$(mktemp)
sort "$CSV_FILE" | uniq | grep -v "^$" > "$TEMP_WALLETS"

# Read the CSV file line by line
while IFS=, read -r wallet || [ -n "$wallet" ]; do
  # Remove any whitespace and quotes
  wallet=$(echo "$wallet" | tr -d '[:space:]' | tr -d '"')
  
  # Skip empty lines
  if [ -z "$wallet" ]; then
    continue
  fi
  
  # Validate the wallet address (basic check for Solana address format)
  if [[ ! $wallet =~ ^[1-9A-HJ-NP-Za-km-z]{32,44}$ ]]; then
    echo "❌ Invalid wallet address format: $wallet - skipping"
    echo "FAILED: $wallet - Invalid format" >> $LOG_FILE
    FAILED_COUNT=$((FAILED_COUNT + 1))
    continue
  fi
  
  echo "[$((SUCCESS_COUNT + FAILED_COUNT + 1))/$TOTAL_WALLETS] Transferring $TOKEN_AMOUNT SLTO to $wallet..."
  
  # Attempt to transfer tokens (3 retries on failure)
  MAX_RETRIES=3
  retry_count=0
  success=false
  
  while [ $retry_count -lt $MAX_RETRIES ] && [ "$success" = false ]; do
    # Use the built-in spl-token transfer command (the override is already active)
    if spl-token transfer $TOKEN_ADDRESS $TOKEN_AMOUNT $wallet --fund-recipient; then
      echo "✅ Successfully sent $TOKEN_AMOUNT SLTO to $wallet"
      echo "SUCCESS: $wallet - $TOKEN_AMOUNT SLTO" >> $LOG_FILE
      SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
      success=true
    else
      retry_count=$((retry_count + 1))
      if [ $retry_count -lt $MAX_RETRIES ]; then
        echo "⚠️ Failed, retrying ($retry_count/$MAX_RETRIES)..."
        sleep 2
      else
        echo "❌ Failed to send tokens to $wallet after $MAX_RETRIES attempts"
        echo "FAILED: $wallet - Transfer failed after $MAX_RETRIES attempts" >> $LOG_FILE
        FAILED_COUNT=$((FAILED_COUNT + 1))
      fi
    fi
  done
  
  # Add a small delay to avoid rate limiting
  sleep 1
done < "$TEMP_WALLETS"

# Clean up temporary file
rm "$TEMP_WALLETS"

# Show distribution summary
echo
echo "Distribution complete!"
echo "Total successful transfers: $SUCCESS_COUNT"
echo "Total failed transfers: $FAILED_COUNT"
echo "Log saved to: $LOG_FILE"

# Show updated token accounts
echo "Updated token accounts:"
spl-token accounts $TOKEN_ADDRESS --program-2022