# Solotto Token Setup Procedure

This document outlines the complete step-by-step process to set up a new Solotto token with its lottery functionality.

## Step 1: Create the Token

Run the token creation script:

```bash
./create_token_with_metadata.sh
```

This will:
- Create a new token with 1% transfer fee
- Mint 18 billion tokens
- Set up the token metadata

Take note of the token address printed at the end of the process. You'll need it for the next steps.

## Step 2: Set Up the Lottery Command Override

Run the following command to install the command override system:

```bash
./override_spl_commands.sh
```

Then update it to use your new token address:

```bash
./update_solotto_token.sh YOUR_NEW_TOKEN_ADDRESS
```

This ensures that every `spl-token transfer` command involving your token will automatically send 1% to the current lottery winner.

## Step 3: Initialize the Lottery System

Create the lottery data directory:

```bash
mkdir -p /home/ed/solotto/lottery_data
```

Set up the initial winner (your own wallet address) until the first drawing:

```bash
echo "YOUR_WALLET_ADDRESS" > /home/ed/solotto/lottery_data/current_winner.txt
```

## Step 4: Set Up Weekly Lottery Automation

Run the script to set up the automated weekly lottery:

```bash
./setup_weekly_lottery.sh YOUR_NEW_TOKEN_ADDRESS
```

This will create a cron job that runs once a week to:
1. Select 4 random holders
2. Choose the one with the highest balance as the winner
3. Save the winner as the recipient of all 1% fees for the next week

## Step 5: Distribute Tokens

Now that everything is set up, you can distribute tokens as needed:

```bash
# Regular transfers will automatically send 1% to the lottery winner
spl-token transfer YOUR_NEW_TOKEN_ADDRESS AMOUNT RECIPIENT_ADDRESS
```

## Important Commands

- **Check Current Winner**:
  ```bash
  cat /home/ed/solotto/lottery_data/current_winner.txt
  ```

- **Run Lottery Manually**:
  ```bash
  ./select_lottery_winner.sh YOUR_NEW_TOKEN_ADDRESS
  ```

- **Update Token Address After Re-minting**:
  ```bash
  ./update_solotto_token.sh NEW_TOKEN_ADDRESS
  ```

## Token Details

- **Name**: Solotto Beta
- **Symbol**: SLTO
- **Decimals**: 9
- **Total Supply**: 18,000,000,000
- **Lottery Fee**: 1% of all transactions