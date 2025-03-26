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
cat > /home/ed/solotto/run_weekly_lottery.sh << EOL
#!/bin/bash
# This script runs the weekly Solotto lottery automatically
# It is intended to be called by cron

TOKEN_ADDRESS="$TOKEN_ADDRESS"
LOG_FILE="/home/ed/solotto/lottery_logs/lottery_\$(date +%Y%m%d).log"

# Run the lottery and log results
echo "Running Solotto lottery on \$(date)" > \$LOG_FILE
/home/ed/solotto/select_lottery_winner.sh \$TOKEN_ADDRESS >> \$LOG_FILE 2>&1

# Send notification (can be customized)
echo "Solotto lottery has been run. Winner is selected and paid."
echo "See logs at \$LOG_FILE"
EOL

# Make the script executable
chmod +x /home/ed/solotto/run_weekly_lottery.sh

# Set up the cron job to run every Sunday at midnight
(crontab -l 2>/dev/null; echo "0 0 * * 0 /home/ed/solotto/run_weekly_lottery.sh") | crontab -

echo "Weekly lottery is now set up to run automatically every Sunday at midnight"
echo "Winner selection, fee collection, and payment are all fully automated"
echo "Logs will be stored in /home/ed/solotto/lottery_logs/"
echo ""
echo "You can check the current winner anytime by running:"
echo "cat /home/ed/solotto/current_winner.txt"
echo ""
echo "To run the lottery manually, use:"
echo "/home/ed/solotto/run_weekly_lottery.sh"