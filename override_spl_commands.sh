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
# Solotto Token wrapper functions for SPL Token and Swap commands

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
    if [[ "$cmd" == "transfer" && "$1" == "46CBCai9pg9WpkkFbWRAnhV9seRNP6ZHm5i4H8D1W9Mu" ]]; then
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
        
        # Calculate 2% for the winner (1% from sender, 1% from receiver)
        # New structure: Take 1% from sender and 1% from receiver = 2% total
        local winner_amount=$(echo "$amount * 0.02" | bc -l | awk '{printf "%.9f", $0}')
        local recipient_amount=$(echo "$amount * 0.98" | bc -l | awk '{printf "%.9f", $0}')
        
        echo "📊 Transfer breakdown:"
        echo "  Original amount: $amount SLTO"
        echo "  Recipient will receive: $recipient_amount SLTO (98%)"
        echo "  Lottery winner will receive: $winner_amount SLTO (2%)"
        echo "  Taking 1% from sender and 1% from recipient"
        
        # Transfer 98% to recipient
        echo "📤 Transferring to recipient..."
        command spl-token transfer "$token" "$recipient_amount" "$recipient" "$@"
        local recipient_status=$?
        
        # If recipient transfer successful, send 2% to winner
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

# Override the swap command (for DEX interactions)
swap() {
    local from_token="$1"
    local amount="$2"
    local to_token="$3"
    shift 3
    local args=("$@")
    
    # Check if receiving Solotto tokens in the swap
    if [[ "$to_token" == "46CBCai9pg9WpkkFbWRAnhV9seRNP6ZHm5i4H8D1W9Mu" ]]; then
        echo "🎲 Solotto token swap detected - applying lottery fee"
        
        # Get current winner
        local winner=$(get_lottery_winner)
        if [ -z "$winner" ]; then
            echo "❌ No current lottery winner found. Running default swap."
            command swap "$from_token" "$amount" "$to_token" "${args[@]}"
            return $?
        fi
        
        echo "🏆 Current lottery winner: $winner"
        
        # For swaps, take 2% from the person receiving Solotto
        echo "📊 Swap will include 2% lottery fee from received Solotto"
        
        # Execute the normal swap
        command swap "$from_token" "$amount" "$to_token" "${args[@]}"
        local swap_status=$?
        
        if [ $swap_status -eq 0 ]; then
            # After swap completes, calculate and transfer 2% of received amount to winner
            # Note: We need to determine how much Solotto was received
            echo "🔍 Checking received Solotto amount..."
            local received_amount=$(spl-token accounts | grep "$to_token" | awk '{print $2}')
            
            # Calculate 2% of the received amount
            local winner_amount=$(echo "$received_amount * 0.02" | bc -l | awk '{printf "%.9f", $0}')
            
            echo "📤 Transferring 2% ($winner_amount SLTO) to lottery winner..."
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
    elif [[ "$from_token" == "46CBCai9pg9WpkkFbWRAnhV9seRNP6ZHm5i4H8D1W9Mu" ]]; then
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
    fi
}

# Export the functions to make them available to subshells
export -f spl-token
export -f swap
export -f get_lottery_winner
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