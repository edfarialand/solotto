#!/bin/bash
# Script to add Metaplex Token Metadata to the Solotto token
# Usage: ./add_metaplex_metadata.sh <TOKEN_ADDRESS>

if [ -z "$1" ]; then
  echo "Error: Token address is required"
  echo "Usage: ./add_metaplex_metadata.sh <TOKEN_ADDRESS>"
  exit 1
fi

TOKEN_ADDRESS=$1
METADATA_URI="https://raw.githubusercontent.com/edfarialand/solotto/master/SOLOTTO_METADATA.json"

# Check if the metaboss command is available
if ! command -v metaboss &> /dev/null; then
  echo "The metaboss command is not installed. Installing now..."
  
  # Install metaboss if not already installed
  curl -LO https://github.com/samuelvanderwaal/metaboss/releases/latest/download/metaboss
  chmod +x metaboss
  sudo mv metaboss /usr/local/bin/
  
  if ! command -v metaboss &> /dev/null; then
    echo "Failed to install metaboss. Please install it manually."
    echo "Visit: https://github.com/samuelvanderwaal/metaboss"
    exit 1
  fi
fi

echo "Adding Metaplex metadata to token: $TOKEN_ADDRESS"

# Create a temporary JSON file with the metadata
TEMP_JSON=$(mktemp)
cat > $TEMP_JSON << EOL
{
  "name": "Solotto Beta",
  "symbol": "SLTO",
  "description": "This is Solotto, a Solana based token with a lottery feature giving the weekly winner 1% of all on chain transactions. Aren't you sick of influencers promising a prize for subscribing or reposting and in the back of your mind you know they're lying and nothing is going to be distributed... and even so, you aren't gonna win? This is what you need. This is a coin that will guarantee you at least still have the Solotto in your wallet after every drawing and maybe more. The code is open source and hosted on our github for all to see and what is even better, YOU CAN SEE THE TRANSACTIONS. YOU CAN SEE THE MONEY GOING INTO THAT WEEKS WINNERS ADDRESS. THE BLOCKCHAIN SPEAKS FOR ITSELF. So do your own research and be safe with your investments but i have one question. What lottery ticket holds value after drawing? None but Solotto. There are no lottery tickets. Owning the currency is your entry so even if you dont win this weeks drawing, you can sell your Solotto making this the smartest lottery on top of the most transparent. Smart. Transparent. Solotto.",
  "image": "https://raw.githubusercontent.com/edfarialand/solotto/ce712299cb50bf0fe118bd6e6384741b5f73e4e7/pressd.png",
  "external_url": "https://solotto.io",
  "attributes": [
    {
      "trait_type": "Token Standard",
      "value": "Token-2022"
    },
    {
      "trait_type": "Token Type",
      "value": "Utility"
    },
    {
      "trait_type": "Total Supply",
      "value": "18,000,000,000"
    },
    {
      "trait_type": "Decimals",
      "value": "9"
    },
    {
      "trait_type": "Transfer Fee",
      "value": "1%"
    },
    {
      "trait_type": "Creator Fee",
      "value": "1%"
    },
    {
      "trait_type": "Lottery Cycle",
      "value": "7 Days"
    }
  ]
}
EOL

echo "Created temporary metadata JSON"

# Create the Metaplex metadata for the token using metaboss
echo "Creating Metaplex metadata using metaboss..."
metaboss create metadata \
  --keypair /home/ed/solotto/solotto_wallet.json \
  --mint $TOKEN_ADDRESS \
  --name "Solotto Beta" \
  --symbol "SLTO" \
  --uri $METADATA_URI

echo "✅ Metaplex metadata created successfully!"
echo "Token: $TOKEN_ADDRESS"
echo "Metadata URI: $METADATA_URI"

# Clean up
rm $TEMP_JSON

echo "The Metaplex Token Metadata program has been successfully integrated with your Solotto token."
echo "This provides additional compatibility with wallets and explorers."
echo ""
echo "You can view your token metadata on:"
echo "- Solscan: https://solscan.io/token/${TOKEN_ADDRESS}"
echo "- Solana Explorer: https://explorer.solana.com/address/${TOKEN_ADDRESS}"