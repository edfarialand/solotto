# 🎟️ Solotto (SLTO)

![Solotto Banner](https://raw.githubusercontent.com/solana-labs/token-list/main/assets/mainnet/So11111111111111111111111111111111111111112/logo.png)

A revolutionary lottery token on Solana with automatic rewards for holders. Every week, four random wallets are selected and the holder with the highest balance wins 1% of all transaction fees for the next week!

## 🚀 Features

- **Dual Fee Structure:** 
  - 1% of all transactions goes to the creator
  - 1% of all transactions goes to the weekly lottery winner

- **Weekly Lottery:**
  - Every 7 days, a new winner is selected
  - Selection process:
    1. Four wallets are randomly selected from all holders
    2. Among those four, the wallet with the highest token balance becomes the winner
    3. The winner automatically receives 1% of all transactions for the next week

- **No Manual Claiming:**
  - Fees are automatically transferred during transactions
  - Winners receive their rewards directly without having to claim them

## 📊 Tokenomics

- **Total Supply:** 50,000,000,000 SLTO
- **Distribution:**
  * 40% Liquidity Pool (20,000,000,000 SLTO)
  * 30% Community Rewards (15,000,000,000 SLTO)
  * 20% Marketing & Partnerships (10,000,000,000 SLTO)
  * 10% Team & Development (5,000,000,000 SLTO)

## 💻 Technical Details

- Built with Anchor Framework
- Uses Token-2022 standard for transfer fees
- Transparent on-chain randomization for winner selection
- Solana blockchain for fast, low-cost transactions

## 🛠️ Development

### Prerequisites

- Solana CLI
- Anchor Framework
- Rust

### Build and Deploy

```bash
# Install dependencies
yarn install

# Build the program
anchor build

# Deploy to devnet
anchor deploy --provider.cluster devnet

# Test
anchor test
```

### Create Token with Metadata

```bash
# Run the token creation script
./create_token_with_metadata.sh
```

## 🔗 Links

- Website: [https://solotto.io](https://solotto.io)
- Twitter: [@SolottoToken](https://twitter.com/SolottoToken)
- Telegram: [https://t.me/solottotoken](https://t.me/solottotoken)
- Discord: [https://discord.gg/solotto](https://discord.gg/solotto)

## 📄 License

This project is licensed under the ISC License.

## ⚠️ Security Notice

This code has not been audited. Use at your own risk.