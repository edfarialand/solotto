#!/bin/bash
# Script to override standard spl-token commands to add Solotto's custom lottery functionality
# This creates wrapper functions that will automatically handle the 1% distribution to the lottery winner

# Path to lottery data
LOTTERY_DATA="/home/ed/solotto/lottery_data"
WINNER_FILE="${LOTTERY_DATA}/current_winner.txt"

# Create directory if it doesn't exist
mkdir -p "${LOTTERY_DATA}"

# Create the wrapper functions file
cat > ~/.solotto_wrappers << 'EOL'
# Solotto Token wrapper functions for SPL Token commands

# Get the current Solotto token address
get_solotto_token() {
    # This function will return the current Solotto token address
    # You can update this if you mint a new token
    echo "SOLOTTO_TOKEN_ADDRESS_PLACEHOLDER"
}

# Get the current lottery winner
get_lottery_winner() {
    if [ ! -f "/home/ed/solotto/lottery_data/current_winner.txt" ]; then
        echo ""
        return 1
    fi
    
    head -1 "/home/ed/solotto/lottery_data/current_winner.txt"
    return 0
}

# Override the spl-token transfer command
spl-token() {
    # Get command and arguments
    local cmd="$1"
    shift
    local args=("$@")

    # Check if this is the Solotto token and a transfer command
    if [[ "$cmd" == "transfer" && "$1" == "$(get_solotto_token)" ]]; then
        echo "🎲 Solotto token detected - using lottery distribution transfer"
        
        # Extract token, amount, and recipient from arguments
        local token="$1"
        local amount="$2"
        local recipient="$3"
        shift 3
        
        # Get current winner
        local winner=$(get_lottery_winner)
        if [ -z "$winner" ]; then
            echo "❌ No current lottery winner found. Running default transfer."
            command spl-token transfer "$token" "$amount" "$recipient" "$@"
            return $?
        fi
        
        echo "🏆 Current lottery winner: $winner"
        
        # Calculate 1% for the winner
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

# Override the standard swap command
swap() {
    local from_token="$1"
    local amount="$2"
    local to_token="$3"
    shift 3
    local args=("$@")
    
    local solotto_token=$(get_solotto_token)
    
    # Check if receiving Solotto tokens in the swap
    if [[ "$to_token" == "$solotto_token" ]]; then
        echo "🎲 Solotto token swap detected - applying lottery fee"
        
        # Get current winner
        local winner=$(get_lottery_winner)
        if [ -z "$winner" ]; then
            echo "❌ No current lottery winner found. Running default swap."
            command swap "$from_token" "$amount" "$to_token" "${args[@]}"
            return $?
        fi
        
        echo "🏆 Current lottery winner: $winner"
        
        # For swaps, take 1% from the person receiving Solotto
        echo "📊 Swap will include 1% lottery fee from received Solotto"
        
        # Execute the normal swap
        command swap "$from_token" "$amount" "$to_token" "${args[@]}"
        local swap_status=$?
        
        if [ $swap_status -eq 0 ]; then
            # After swap completes, calculate and transfer 1% of received amount to winner
            # Note: We need to determine how much Solotto was received
            echo "🔍 Checking received Solotto amount..."
            local received_amount=$(command spl-token accounts | grep "$to_token" | awk '{print $2}')
            
            # Calculate 1% of the received amount
            local winner_amount=$(echo "$received_amount * 0.01" | bc -l | awk '{printf "%.9f", $0}')
            
            echo "📤 Transferring 1% ($winner_amount SLTO) to lottery winner..."
            command spl-token transfer "$to_token" "$winner_amount" "$winner" --fund-recipient
            local winner_status=$?
            
            if [ $winner_status -eq 0 ]; then
                echo "✅ Solotto lottery swap fee complete!"
            else
                echo "⚠️ Warning: Could not send swap fee to lottery winner."
            fi
            
            return $swap_status
        else
            echo "❌ Error: Swap failed."
            return $swap_status
        fi
    
    # Check if sending Solotto tokens in the swap
    elif [[ "$from_token" == "$solotto_token" ]]; then
        echo "🎲 Sending Solotto token in swap - applying lottery fee"
        
        # Get current winner
        local winner=$(get_lottery_winner)
        if [ -z "$winner" ]; then
            echo "❌ No current lottery winner found. Running default swap."
            command swap "$from_token" "$amount" "$to_token" "${args[@]}"
            return $?
        fi
        
        echo "🏆 Current lottery winner: $winner"
        
        # Calculate 1% for the lottery when sending Solotto
        local lottery_amount=$(echo "$amount * 0.01" | bc -l | awk '{printf "%.9f", $0}')
        local swap_amount=$(echo "$amount * 0.99" | bc -l | awk '{printf "%.9f", $0}')
        
        echo "📊 Swap breakdown:"
        echo "  Original amount: $amount SLTO"
        echo "  Amount for swap: $swap_amount SLTO (99%)"
        echo "  Lottery winner will receive: $lottery_amount SLTO (1%)"
        
        # Send 1% to lottery winner first
        echo "📤 Transferring to lottery winner..."
        command spl-token transfer "$from_token" "$lottery_amount" "$winner" --fund-recipient
        
        # Then execute swap with remaining amount
        echo "🔄 Executing swap..."
        command swap "$from_token" "$swap_amount" "$to_token" "${args[@]}"
        return $?
    else
        # Not a Solotto swap, execute normal command
        command swap "$from_token" "$amount" "$to_token" "${args[@]}"
        return $?
    fi
}

# Export the functions to make them available to subshells
export -f spl-token
export -f swap
export -f get_lottery_winner
export -f get_solotto_token
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

# Function to update the Solotto token address
cat > ./update_solotto_token.sh << 'EOL'
#!/bin/bash
# Script to update the Solotto token address used in the command overrides
# Usage: ./update_solotto_token.sh <TOKEN_ADDRESS>

if [ -z "$1" ]; then
    echo "Error: Token address is required"
    echo "Usage: ./update_solotto_token.sh <TOKEN_ADDRESS>"
    exit 1
fi

TOKEN_ADDRESS=$1

# Update the token address in the wrappers file
sed -i "s/echo \"[a-zA-Z0-9]*\"/echo \"$TOKEN_ADDRESS\"/g" ~/.solotto_wrappers

echo "✅ Solotto token address updated to: $TOKEN_ADDRESS"
echo "The override commands will now use this token address for lottery functionality."
EOL

chmod +x ./update_solotto_token.sh

echo ""
echo "🎲 Solotto command overrides have been installed!"
echo ""
echo "Now the standard spl-token transfer command will automatically:"
echo "  - Send 99% to the recipient"
echo "  - Send 1% to the current lottery winner"
echo ""
echo "Similarly, swap commands involving Solotto will also contribute to the lottery."
echo ""
echo "To enable in your current terminal session, run:"
echo "  source ./enable_solotto_overrides.sh"
echo ""
echo "After minting a new token, update its address with:"
echo "  ./update_solotto_token.sh <NEW_TOKEN_ADDRESS>"
echo ""
echo "The override will be automatically enabled in all new terminal sessions."
echo "To disable temporarily, run: 'unset -f spl-token swap'"