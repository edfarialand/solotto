#!/bin/bash
# Script to override standard spl-token commands to add Solotto's custom lottery functionality
# This creates wrapper functions that will automatically handle the 1% distribution to the lottery winner

# Token address - Replace with your actual token address
SOLOTTO_TOKEN="46CBCai9pg9WpkkFbWRAnhV9seRNP6ZHm5i4H8D1W9Mu"

# Path to lottery data
LOTTERY_DATA="/home/ed/solotto/lottery_data"
WINNER_FILE="${LOTTERY_DATA}/current_winner.txt"

# Create directory if it doesn't exist
mkdir -p "${LOTTERY_DATA}"

# Function to check if a command is being run on Solotto token
is_solotto_operation() {
    local args="$*"
    if [[ "$args" == *"$SOLOTTO_TOKEN"* ]]; then
        return 0 # True
    else
        return 1 # False
    fi
}

# Create the wrapper functions file
cat > ~/.solotto_wrappers << 'EOL'
# Solotto Token wrapper functions for SPL Token commands

# Override the spl-token transfer command
spl-token() {
    # Get command and arguments
    local cmd="$1"
    shift
    local args=("$@")

    # Check if this is the Solotto token and a transfer command
    if [[ "$cmd" == "transfer" && "$1" == "46CBCai9pg9WpkkFbWRAnhV9seRNP6ZHm5i4H8D1W9Mu" ]]; then
        echo "🎲 Solotto token detected - using lottery distribution transfer"
        
        # Extract token, amount, and recipient from arguments
        local token="$1"
        local amount="$2"
        local recipient="$3"
        shift 3
        
        # Check if winner file exists
        if [ ! -f "/home/ed/solotto/lottery_data/current_winner.txt" ]; then
            echo "❌ No current lottery winner found. Running default transfer."
            command spl-token transfer "$token" "$amount" "$recipient" "$@"
            return $?
        fi
        
        # Read current winner
        local winner=$(head -1 "/home/ed/solotto/lottery_data/current_winner.txt")
        echo "🏆 Current lottery winner: $winner"
        
        # Calculate 1% for the winner
        # Using bc for accurate floating point calculation
        local winner_amount=$(echo "$amount * 0.01" | bc -l | awk '{printf "%.9f", $0}')
        local recipient_amount=$(echo "$amount * 0.99" | bc -l | awk '{printf "%.9f", $0}')
        
        echo "📊 Transfer breakdown:"
        echo "  Original amount: $amount SLTO"
        echo "  Recipient will receive: $recipient_amount SLTO (99%)"
        echo "  Lottery winner will receive: $winner_amount SLTO (1%)"
        
        # Transfer 99% to recipient
        echo "📤 Transferring to recipient..."
        command spl-token transfer "$token" "$recipient_amount" "$recipient" "$@"
        local recipient_status=$?
        
        # If recipient transfer successful, send 1% to winner
        if [ $recipient_status -eq 0 ]; then
            echo "📤 Transferring to lottery winner..."
            command spl-token transfer "$token" "$winner_amount" "$winner" --fund-recipient
            local winner_status=$?
            
            if [ $winner_status -eq 0 ]; then
                echo "✅ Solotto lottery transfer complete!"
                return 0
            else
                echo "⚠️ Warning: Could not send to lottery winner. Main transfer successful."
                return $winner_status
            fi
        else
            echo "❌ Error: Main transfer failed."
            return $recipient_status
        fi
    else
        # If not Solotto or not a transfer, execute normal command
        command spl-token "$cmd" "${args[@]}"
    fi
}

# Export the function to make it available to subshells
export -f spl-token
EOL

# Make it executable
chmod +x ~/.solotto_wrappers

# Add to .bashrc if not already there
if ! grep -q "source ~/.solotto_wrappers" ~/.bashrc; then
    echo "" >> ~/.bashrc
    echo "# Solotto Token command overrides" >> ~/.bashrc
    echo "source ~/.solotto_wrappers" >> ~/.bashrc
    echo "Added Solotto command overrides to ~/.bashrc"
fi

# Create a file that can be sourced for current session
echo "# Source this file to enable Solotto overrides in current session" > ./enable_solotto_overrides.sh
echo "source ~/.solotto_wrappers" >> ./enable_solotto_overrides.sh
chmod +x ./enable_solotto_overrides.sh

echo ""
echo "🎲 Solotto command overrides have been installed!"
echo ""
echo "Any spl-token transfer operations for token $SOLOTTO_TOKEN will now"
echo "automatically send 1% to the current lottery winner."
echo ""
echo "To enable in your current terminal session, run:"
echo "  source ./enable_solotto_overrides.sh"
echo ""
echo "The override will be automatically enabled in all new terminal sessions."
echo "To disable temporarily, run: 'unset -f spl-token'"