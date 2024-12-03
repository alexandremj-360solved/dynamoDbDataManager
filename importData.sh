#!/bin/bash

echo "***************************************************************************************"
echo "Welcome to DynamoDB Data Batch Importer"
echo "This script will import your DynamoDB data to AWS using 'aws dynamodb batch-write-item'"
echo "Before starting, make sure your AWS configuration is correct"

echo "Please enter the AWS region where you want to import the data: "
read -e aws_region_name

echo "Please enter the AWS profile name for the target account: "
read -e aws_profile_name

start_time="$(date -u +%s)"

# Find all tables (directories) that have been exported
table_dirs=($(find . -maxdepth 1 -type d -not -path '.' -not -path './.*'))

echo "Found the following tables to import:"
for dir in "${table_dirs[@]}"; do
    echo "- ${dir#./}"
done

echo "Do you want to import data for all these tables? [Y/N]"
read -e confirmImport

if [[ "$confirmImport" == "Y" || "$confirmImport" == "y" ]]
then
    for table_dir in "${table_dirs[@]}"; do
        table_name=${table_dir#./}
        script_dir="$table_dir/ScriptForDataImport"

        if [ -d "$script_dir" ]; then
            echo "Importing data for table: $table_name"

            for filename in "$script_dir"/*.txt; do
                echo "Importing ${filename}"
                aws dynamodb batch-write-item --region "$aws_region_name" --profile "$aws_profile_name" --request-items file://"$filename"
            done

            echo "Completed importing data for table: $table_name"
            echo "***************************************************************************************"
        else
            echo "No data found to import for table: $table_name"
        fi
    done

    echo "Import process completed."
    echo "***************************************************************************************"
    end_func_time="$(date -u +%s)"
    echo "A total of $(($end_func_time-$start_time)) seconds were used to complete the function"
else
    echo "Import canceled."
fi
