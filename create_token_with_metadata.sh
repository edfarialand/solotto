#!/bin/bash
# Script to create Solotto token with metadata and optionally distribute to wallets
# Usage: ./create_token_with_metadata.sh [CSV_FILE] [AMOUNT_PER_WALLET]
#
# If a CSV file with wallet addresses is provided, tokens will be distributed
# to those wallets after creation. Amount per wallet can be specified as
# the second parameter (defaults to 1000 if not specified).

# Make sure you're on the right network before running this script
# solana config set --url https://api.testnet.solana.com  # For testnet
# solana config set --url https://api.mainnet-beta.solana.com  # For mainnet

# Ensure lottery data directory exists
mkdir -p /home/ed/solotto/lottery_data

# Create placeholder for first lottery winner (token creator initially)
echo "Creating initial lottery winner configuration..."
INITIAL_WINNER=$(solana address)
echo "$INITIAL_WINNER" > /home/ed/solotto/lottery_data/current_winner.txt
echo "$(date +"%Y-%m-%d")" >> /home/ed/solotto/lottery_data/current_winner.txt
echo "Initial winner (you): $INITIAL_WINNER"

# Create token with 1% transfer fee for the lottery system
# This fee automatically goes to the TRANSFER FEE AUTHORITY account
# We'll need to regularly withdraw and distribute it to the weekly winner
echo "Creating Solotto token with 1% transfer fee for lottery mechanism..."
TOKEN_ADDRESS=$(spl-token create-token --program-2022 --transfer-fee 100 10000 --decimals 9 | grep "Address:" | awk '{print $2}')
echo "Token created with address: $TOKEN_ADDRESS"

# Create token account
echo "Creating token account..."
spl-token create-account $TOKEN_ADDRESS --program-2022

# Mint 50 billion tokens
echo "Minting 50,000,000,000 tokens..."
spl-token mint $TOKEN_ADDRESS 50000000000 --program-2022

# Initialize metadata with token info
echo "Initializing token metadata..."
# Create a metadata URL - this would typically be a hosted JSON file with your full description
# For now we'll just use the image URL, but you should replace this with your metadata JSON URL
# that points to a hosted version of SOLOTTO_METADATA.json
METADATA_URL="https://raw.githubusercontent.com/solotto/solotto/main/SOLOTTO_METADATA.json"

# Set token icon URL from your GitHub repo
ICON_URL="https://raw.githubusercontent.com/edfarialand/solotto/ce712299cb50bf0fe118bd6e6384741b5f73e4e7/pressd.png"

# Initialize metadata with your custom icon
spl-token initialize-metadata $TOKEN_ADDRESS "Solotto" "SLTO" "$ICON_URL" --program-2022

# Display a note about the metadata with your description
echo "Token metadata initialized with the following description:"
echo "--------------------------------------------------------------------------------"
echo "This is Solotto, a Solana based token with a lottery feature giving the weekly winner 1% of all on chain transactions. Aren't you sick of influencers promising a prize for subscribing or reposting and in the back of your mind you know they're lying and nothing is going to be distributed... and even so, you aren't gonna win? This is what you need. This is a coin that will guarantee you at least still have the Solotto in your wallet after every drawing and maybe more. The code is open source and hosted on our github for all to see and what is even better, YOU CAN SEE THE TRANSACTIONS. YOU CAN SEE THE MONEY GOING INTO THAT WEEKS WINNERS ADDRESS. THE BLOCKCHAIN SPEAKS FOR ITSELF. So do your own research and be safe with your investments but i have one question. What lottery ticket holds value after drawing? None but Solotto. There are no lottery tickets. Owning the currency is your entry so even if you dont win this weeks drawing, you can sell your Solotto making this the smartest lottery on top of the most transparent. Smart. Transparent. Solotto."
echo "--------------------------------------------------------------------------------"

# Display token details
echo "Token details:"
spl-token display $TOKEN_ADDRESS --program-2022

echo "Solotto token creation complete!"

# Create the lottery winner selection script
cat > /home/ed/solotto/select_lottery_winner.sh << 'EOL'
#!/bin/bash
# Script to select a lottery winner from Solotto token holders
# Usage: ./select_lottery_winner.sh <TOKEN_ADDRESS>

if [ -z "$1" ]; then
  echo "Error: Token address is required"
  echo "Usage: ./select_lottery_winner.sh <TOKEN_ADDRESS>"
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

# Withdraw withheld tokens to winner
echo ""
echo "Withdrawing accumulated transfer fees and sending directly to winner..."
WITHDRAW_OUTPUT=$(spl-token withdraw-withheld-tokens $TOKEN_ADDRESS --program-2022 2>&1)
echo "Fee withdrawal result: $WITHDRAW_OUTPUT"

# Get current balance to transfer to winner
CURRENT_BALANCE=$(spl-token balance $TOKEN_ADDRESS --program-2022)
if [[ $CURRENT_BALANCE -gt 0 ]]; then
  echo "Transferring $CURRENT_BALANCE SLTO to winner: $WINNER_ADDR"
  spl-token transfer $TOKEN_ADDRESS $CURRENT_BALANCE $WINNER_ADDR --program-2022 --fund-recipient
  echo "✅ Transfer complete! Winner has received their prize."
else
  echo "No accumulated fees to transfer at this time."
fi

# Save the current winner to a file for the custom transfer function
echo "Updating current winner information..."
mkdir -p /home/ed/solotto/lottery_data
echo "$WINNER_ADDR" > /home/ed/solotto/lottery_data/current_winner.txt
echo "$(date +"%Y-%m-%d")" >> /home/ed/solotto/lottery_data/current_winner.txt

# Update history of winners
echo "$WINNER_ADDR,$(date +"%Y-%m-%d"),$WINNER_BALANCE,$CURRENT_BALANCE" >> /home/ed/solotto/lottery_data/winner_history.csv

# Clean up temporary files
rm $ACCOUNTS_FILE $HOLDERS_FILE $SELECTED_FILE
EOL

# Create the transfer wrapper function that sends 1% to current winner
cat > /home/ed/solotto/solotto_transfer.sh << 'EOL'
#!/bin/bash
# Script to transfer Solotto tokens with 1% going to current lottery winner
# Usage: ./solotto_transfer.sh <TOKEN_ADDRESS> <AMOUNT> <RECIPIENT>

if [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ]; then
  echo "Error: All parameters are required"
  echo "Usage: ./solotto_transfer.sh <TOKEN_ADDRESS> <AMOUNT> <RECIPIENT>"
  exit 1
fi

TOKEN_ADDRESS=$1
AMOUNT=$2
RECIPIENT=$3
WINNER_FILE="/home/ed/solotto/lottery_data/current_winner.txt"

# Check if winner file exists
if [ ! -f "$WINNER_FILE" ]; then
  echo "No current lottery winner found. Please run select_lottery_winner.sh first."
  exit 1
fi

# Read current winner
WINNER=$(head -1 "$WINNER_FILE")
echo "Current lottery winner: $WINNER"

# Calculate 1% for the winner
WINNER_AMOUNT=$(echo "$AMOUNT * 0.01" | bc -l | awk '{printf "%.9f", $0}')
RECIPIENT_AMOUNT=$(echo "$AMOUNT * 0.99" | bc -l | awk '{printf "%.9f", $0}')

echo "Original amount: $AMOUNT SLTO"
echo "Recipient will receive: $RECIPIENT_AMOUNT SLTO (99%)"
echo "Lottery winner will receive: $WINNER_AMOUNT SLTO (1%)"

# Transfer 99% to recipient
echo "Transferring to recipient..."
spl-token transfer $TOKEN_ADDRESS $RECIPIENT_AMOUNT $RECIPIENT --program-2022 --fund-recipient

# Transfer 1% to winner
echo "Transferring to lottery winner..."
spl-token transfer $TOKEN_ADDRESS $WINNER_AMOUNT $WINNER --program-2022 --fund-recipient

echo "✅ Transfer complete!"
echo "This custom transfer maintains the same 1% fee model as the token's built-in transfer fee"
echo "but sends it directly to the current lottery winner's wallet."
EOL

# Create the setup script for weekly lottery
cat > /home/ed/solotto/setup_weekly_lottery.sh << 'EOL'
#!/bin/bash
# Script to set up weekly automated lottery for Solotto token
# Usage: ./setup_weekly_lottery.sh <TOKEN_ADDRESS>

if [ -z "$1" ]; then
  echo "Error: Token address is required"
  echo "Usage: ./setup_weekly_lottery.sh <TOKEN_ADDRESS>"
  exit 1
fi

TOKEN_ADDRESS=$1

# Create a directory for lottery logs
mkdir -p /home/ed/solotto/lottery_logs

# Create the weekly lottery script runner
cat > /home/ed/solotto/run_weekly_lottery.sh << EOLS
#!/bin/bash
# This script runs the weekly Solotto lottery automatically
# It is intended to be called by cron

TOKEN_ADDRESS="$TOKEN_ADDRESS"
LOG_FILE="/home/ed/solotto/lottery_logs/lottery_\$(date +%Y%m%d).log"

# Run the lottery and log results
echo "Running Solotto lottery on \$(date)" > \$LOG_FILE
/home/ed/solotto/select_lottery_winner.sh \$TOKEN_ADDRESS >> \$LOG_FILE 2>&1

# Send notification (can be customized)
echo "Solotto lottery has been run. New winner is selected."
echo "See logs at \$LOG_FILE"
EOLS

# Make the script executable
chmod +x /home/ed/solotto/run_weekly_lottery.sh

# Set up the cron job to run every Sunday at midnight
(crontab -l 2>/dev/null; echo "0 0 * * 0 /home/ed/solotto/run_weekly_lottery.sh") | crontab -

echo "Weekly lottery is now set up to run automatically every Sunday at midnight"
echo "Winner selection and transfer fee collection are all fully automated"
echo "Logs will be stored in /home/ed/solotto/lottery_logs/"
echo ""
echo "You can check the current winner anytime by running:"
echo "cat /home/ed/solotto/lottery_data/current_winner.txt"
echo ""
echo "To run the lottery manually, use:"
echo "/home/ed/solotto/run_weekly_lottery.sh"
EOL

# Make scripts executable
chmod +x /home/ed/solotto/select_lottery_winner.sh
chmod +x /home/ed/solotto/solotto_transfer.sh
chmod +x /home/ed/solotto/setup_weekly_lottery.sh

# Distribute tokens from CSV if file is provided
if [ -n "$1" ]; then
  CSV_FILE=$1
  TOKEN_AMOUNT=${2:-1000}  # Default to 1000 if not specified
  
  # Check if CSV file exists
  if [ ! -f "$CSV_FILE" ]; then
    echo "Error: CSV file not found at $CSV_FILE"
    exit 1
  fi
  
  # Get the configured wallet
  CONFIGURED_WALLET=$(solana address)
  echo "Using wallet: $CONFIGURED_WALLET"
  
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
    
    # Attempt to transfer tokens using our custom transfer script (3 retries on failure)
    MAX_RETRIES=3
    retry_count=0
    success=false
    
    while [ $retry_count -lt $MAX_RETRIES ] && [ "$success" = false ]; do
      # Use our custom transfer script that handles winner payment
      if ./solotto_transfer.sh $TOKEN_ADDRESS $TOKEN_AMOUNT $wallet; then
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
fi

echo "Next steps:"
echo "1. Create liquidity pool on Raydium"
echo "2. Set up the weekly lottery system:"
echo "   - Run './setup_weekly_lottery.sh $TOKEN_ADDRESS' to configure automatic weekly drawings"
echo "   - The lottery will run every Sunday at midnight"
echo "3. IMPORTANT: For ALL transfers of SLTO tokens, use:"
echo "   - './solotto_transfer.sh $TOKEN_ADDRESS <AMOUNT> <RECIPIENT>'"
echo "   - This ensures 1% goes directly to the current lottery winner's wallet"
echo "4. Set up social media and website"
echo "5. Begin marketing efforts"
echo ""
echo "Token creation completed! Your token address is: $TOKEN_ADDRESS"
echo ""
echo "Current lottery winner (initially you): $INITIAL_WINNER"
echo "This address will receive 1% of all transfers until the first lottery drawing"