#!/bin/bash

# Shell script to integrate existing DynamoDB scripts

clear
echo "***************************************************************************************"
echo "Welcome to the AWS DynamoDB Management Script"
echo "Please make sure your AWS CLI is configured and 'jq' is installed."
echo "***************************************************************************************"

# Main menu
main_menu() {
    while true; do
        echo "Select an option:"
        echo "1 - Clean up DynamoDB tables"
        echo "2 - Export DynamoDB table data"
        echo "3 - Import DynamoDB table data"
        echo "4 - Exit"
        read -p "Enter your choice: " OPTION

        case $OPTION in
            1)
                echo "Running database cleanup..."
                ./databaseCleanup.sh
                echo "Database cleanup completed. Returning to main menu..."
                ;;
            2)
                echo "Running database export..."
                ./exportData.sh
                echo "Database export completed. Returning to main menu..."
                ;;
            3)
                echo "Running database import..."
                ./importData.sh
                echo "Database import completed. Returning to main menu..."
                ;;
            4)
                echo "Exiting script. Goodbye!"
                exit 0
                ;;
            *)
                echo "Invalid option. Please select a valid option."
                ;;
        esac
    done
}

# Start the script by displaying the menu
main_menu
