# Overriding SPL Token Commands for Solotto

Solotto includes a powerful feature that allows you to use the standard `spl-token` commands with the lottery distribution functionality automatically applied.

## How It Works

When you run the `override_spl_commands.sh` script, it will:

1. Create a wrapper function that intercepts the `spl-token transfer` command
2. Check if the transfer is for the Solotto token
3. If it is, automatically split the transaction:
   - 99% goes to the intended recipient
   - 1% goes to the current lottery winner

## Installation

Run the override script:

```bash
./override_spl_commands.sh
```

This will:
- Create a wrapper function in `~/.solotto_wrappers`
- Add the wrapper to your `~/.bashrc` so it loads automatically in new sessions
- Create a helper script to enable it in your current session

## Usage

After installation, you can simply use the standard SPL token commands:

```bash
# This will automatically split the transfer with 1% to the lottery winner
spl-token transfer 46CBCai9pg9WpkkFbWRAnhV9seRNP6ZHm5i4H8D1W9Mu 1000 RECIPIENT_WALLET
```

You don't need to remember to use any special command - the standard command will automatically apply the lottery distribution for Solotto tokens only.

## Benefits

- Seamlessly integrates with existing wallets and tools
- Users and developers can use standard Solana commands
- 1% lottery distribution happens automatically
- No need to remember a custom command
- Only affects transfers of the Solotto token

## Disabling Temporarily

If you need to disable the override temporarily:

```bash
unset -f spl-token
```

## Re-enabling in Current Session

```bash
source ./enable_solotto_overrides.sh
```

## Note for Developers

When creating applications that interact with Solotto, you can either:

1. Use the standard SPL token transfer and run your app in an environment with the override installed
2. Implement the 1% distribution logic directly in your application

The override approach makes integration simpler for most use cases, especially for command-line interactions.