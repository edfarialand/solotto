#\!/bin/bash
# Script to create Solotto token with metadata on testnet/mainnet

# Make sure you're on the right network before running this script
# solana config set --url https://api.testnet.solana.com  # For testnet
# solana config set --url https://api.mainnet-beta.solana.com  # For mainnet

# Create token with 1% transfer fee
echo "Creating Solotto token with 1% transfer fee..."
TOKEN_ADDRESS=$(spl-token create-token --program-2022 --transfer-fee 100 10000 --decimals 9 | grep "Address:" | awk '{print $2}')
echo "Token created with address: $TOKEN_ADDRESS"

# Create token account
echo "Creating token account..."
spl-token create-account $TOKEN_ADDRESS --program-2022

# Mint 50 billion tokens
echo "Minting 50,000,000,000 tokens..."
spl-token mint $TOKEN_ADDRESS 50000000000 --program-2022

# Initialize metadata
echo "Initializing token metadata..."
spl-token initialize-metadata $TOKEN_ADDRESS "Solotto" "SLTO" "https://raw.githubusercontent.com/solana-labs/token-list/main/assets/mainnet/So11111111111111111111111111111111111111112/logo.png" --program-2022

# Display token details
echo "Token details:"
spl-token display $TOKEN_ADDRESS --program-2022

echo "Solotto token creation complete\!"
echo "Next steps:"
echo "1. Create liquidity pool on Raydium"
echo "2. Deploy the lottery program"
echo "3. Set up social media and website"
echo "4. Begin marketing efforts"
