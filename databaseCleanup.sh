#!/bin/bash
# Perfil y región AWS
echo "***************************************************************************************"
echo "Welcome to the DynamoDB Data Migrator"
echo "This script will clean your DynamoDB data for a provided AWS account."
echo "Before starting, make sure your AWS configurations are correct and that 'jq' is installed."

read -p "Enter AWS Profile [default: AWSAdministratorAccess-XXXXXXXX]: " PROFILE
PROFILE=${PROFILE:-AWSAdministratorAccess-058264404440}

read -p "Enter AWS Region [default: eu-central-1]: " REGION
REGION=${REGION:-eu-central-1}

read -p "Enter Max Jobs for Parallel Processing [default: 8]: " MAX_JOBS
MAX_JOBS=${MAX_JOBS:-8}

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOG_FILE="logs_$TIMESTAMP.json"

# Exportar variáveis para o ambiente
export AWS_EXECUTION_ENV="non-interactive"
export PROFILE
export REGION
export MAX_JOBS
export LOG_FILE

# Função para processar uma tabela
process_table() {
  local TABLE_NAME=$1

  echo "Processing table: $TABLE_NAME"

  # Describe a tabela e salva a configuração em um arquivo JSON
  aws dynamodb describe-table --table-name "$TABLE_NAME" --output json --profile "$PROFILE" --region "$REGION" > "$TABLE_NAME-config.json"
  if [ $? -ne 0 ]; then
    echo "Error describing table $TABLE_NAME"
    exit 1
  fi

  # Limpar o JSON usando jq
  jq '.Table |
      . + {BillingMode: .BillingModeSummary.BillingMode} |
      del(.TableStatus, .CreationDateTime, .ProvisionedThroughput.LastIncreaseDateTime, .ProvisionedThroughput.LastDecreaseDateTime,
          .TableSizeBytes, .ItemCount, .TableArn, .TableId, .ProvisionedThroughput, .BillingModeSummary) |
      if .GlobalSecondaryIndexes != null then 
          .GlobalSecondaryIndexes |= map(del(.IndexStatus, .ProvisionedThroughput.NumberOfDecreasesToday, .IndexSizeBytes, .ItemCount, .IndexArn, .ProvisionedThroughput))
      else . 
      end' "$TABLE_NAME-config.json" > "$TABLE_NAME-config-cleaned.json"
  if [ $? -ne 0 ]; then
    echo "Error cleaning JSON for table $TABLE_NAME."
    exit 1
  fi
  echo "Cleaned JSON ready for table recreation."

  # Remove JSON original
  rm -rf "$TABLE_NAME-config.json"

  # Deletar a tabela
  echo "Deleting table $TABLE_NAME..."
  aws dynamodb delete-table --table-name "$TABLE_NAME" --profile "$PROFILE" --region "$REGION" >> "$LOG_FILE"
  if [ $? -ne 0 ]; then
    echo "Error deleting table $TABLE_NAME."
    exit 1
  fi

  # Garantir que a tabela foi deletada
  aws dynamodb wait table-not-exists --table-name "$TABLE_NAME" --profile "$PROFILE" --region "$REGION"
  echo "Table $TABLE_NAME has been deleted."

  # Recriar a tabela com o JSON limpo
  echo "Recreating table $TABLE_NAME..."
  aws dynamodb create-table --cli-input-json file://"$TABLE_NAME-config-cleaned.json" --profile "$PROFILE" --region "$REGION" >> "$LOG_FILE"
  if [ $? -ne 0 ]; then
    echo "Error recreating table $TABLE_NAME."
    exit 1
  fi

  # Esperar que a tabela esteja disponível
  aws dynamodb wait table-exists --table-name "$TABLE_NAME" --profile "$PROFILE" --region "$REGION"
  echo "Table $TABLE_NAME recreated successfully."

  # Remover o JSON limpo
  rm -rf "$TABLE_NAME-config-cleaned.json"
}

# Exportar função para subshells
export -f process_table

# Listar todas as tabelas e processá-las em paralelo
aws dynamodb list-tables --output json --profile "$PROFILE" --region "$REGION" | jq -r '.TableNames[]' | \
xargs -n 1 -P "$MAX_JOBS" -I {} bash -c 'process_table "$@"' _ {}