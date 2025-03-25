#!/bin/bash
MAJOR='\033[0m'
RESET='\033[0m' # No Color
DOT='\033[0;37m.\033[0m'
start_time=$(date +%s)
timeout=60   # Some setups return a "yellow" and so this allows us to continue on...

echo -e "${MAJOR}Waiting for OpenSearch to start up and be online.${RESET}"
# Wait for opensearch to start...
while [[ "$(curl -s -o /dev/null -w ''%{http_code}'' localhost:9200/_cluster/health)" != "200" ]]; do printf ${DOT}; sleep 5; done

# See if we can get a "green" status...
while [[ "$(curl -s localhost:9200/_cluster/health | jq '."status"')" != "\"green\"" ]]; do
    printf "${DOT}"
    sleep 5

    current_time=$(date +%s)
    elapsed_time=$((current_time - start_time))

    if [[ $elapsed_time -ge $timeout ]]; then
        echo -e "${MAJOR}Timeout waiting for 'green' OpenSearch status reached. Proceeding on..${RESET}"
        break
    fi
done

echo ""


if [ ! -f ./tmdb_os.json ]; then
  unzip tmdb_os.json.zip
fi

curl -XDELETE "http://localhost:9200/tmdb";

#curl -XPUT "http://localhost:9200/tmdb/" -H 'Content-Type: application/json' --data-binary @schema.json;

#curl -XPOST "http://localhost:9200/tmdb/_bulk" -H 'Content-Type: application/json' --data-binary @tmdb_es.json;

echo -e "${MAJOR}Configuring the ML Commons plugin.${RESET}"
curl -s -X PUT "http://localhost:9200/_cluster/settings" -H 'Content-Type: application/json' --data-binary '{
  "persistent": {
        "plugins": {
            "ml_commons": {
                "only_run_on_ml_node": "false",
                "model_access_control_enabled": "true",
                "native_memory_threshold": "99"
            }
        }
    }
}'

echo -e "${MAJOR}Registering a model group.${RESET}"
response=$(curl -s -X POST "http://localhost:9200/_plugins/_ml/model_groups/_register" \
  -H 'Content-Type: application/json' \
  --data-binary '{
    "name": "neural_search_model_group",
    "description": "A model group for neural search models"
  }')

# Extract the model_group_id from the JSON response
model_group_id=$(echo "$response" | jq -r '.model_group_id')

# Use the extracted model_group_id
echo -e "${MAJOR}Created Model Group with id: $model_group_id${RESET}"

echo -e "${MAJOR}Registering a model in the model group.${RESET}"
response=$(curl -s -X POST "http://localhost:9200/_plugins/_ml/models/_register" \
  -H 'Content-Type: application/json' \
  --data-binary "{
     \"name\": \"huggingface/sentence-transformers/all-MiniLM-L6-v2\",
     \"version\": \"1.0.1\",
     \"model_group_id\": \"$model_group_id\",
     \"model_format\": \"TORCH_SCRIPT\"
  }")

# Extract the task_id from the JSON response
task_id=$(echo "$response" | jq -r '.task_id')

# Use the extracted task_id
echo -e "${MAJOR}Created Model, get status with task id: $task_id"


echo -e "${MAJOR}Waiting for the model to be registered.${RESET}"
max_attempts=10
attempts=0

# Wait for task to be COMPLETED
while [[ "$(curl -s localhost:9200/_plugins/_ml/tasks/$task_id | jq -r '.state')" != "COMPLETED" && $attempts -lt $max_attempts ]]; do
    echo -e "${MAJOR}Waiting for task to complete... attempt $((attempts + 1))/$max_attempts${RESET}"
    sleep 5
    attempts=$((attempts + 1))
done

if [[ $attempts -ge $max_attempts ]]; then
    echo -e "${MAJOR}Limit of attempts reached. Something went wrong with registering the model. Check OpenSearch logs.${RESET}"
    exit 1
else
    response=$(curl -s localhost:9200/_plugins/_ml/tasks/$task_id)
    model_id=$(echo "$response" | jq -r '.model_id')
    echo -e "${MAJOR}Task completed successfully! Model registered with id: $model_id${RESET}"
fi

echo -e "${MAJOR}Deploying the model.${RESET}"
response=$(curl -s -X POST "http://localhost:9200/_plugins/_ml/models/$model_id/_deploy")

# Extract the task_id from the JSON response
deploy_task_id=$(echo "$response" | jq -r '.task_id')

echo -e "${MAJOR}Model deployment started, get status with task id: $deploy_task_id${RESET}"

echo -e "${MAJOR}Waiting for the model to be deployed.${RESET}"
# Reset attempts
attempts=0

while [[ "$(curl -s localhost:9200/_plugins/_ml/tasks/$task_id | jq -r '.state')" != "COMPLETED" && $attempts -lt $max_attempts ]]; do
    echo -e "${MAJOR}Waiting for task to complete... attempt $((attempts + 1))/$max_attempts${RESET}"
    sleep 5
    attempts=$((attempts + 1))
done

if [[ $attempts -ge $max_attempts ]]; then
    echo -e "${MAJOR}Limit of attempts reached. Something went wrong with deploying the model. Check OpenSearch logs.${RESET}"
else
    echo -e "${MAJOR}Checking model status."
    attempts=0
    while [[ "$(curl -s "http://localhost:9200/_plugins/_ml/models/$model_id" | jq -r '.model_state')" != "DEPLOYED" && $attempts -lt $max_attempts ]]; do
      echo -e "${MAJOR}Waiting for model to be completely deployed and available... attempt $((attempts + 1))/$max_attempts${RESET}"
      sleep 5
      attempts=$((attempts + 1))
    done
    if [[ $attempts -ge $max_attempts ]]; then
      echo -e "${MAJOR}Limit of attempts reached. Something went wrong with deploying the model. Check OpenSearch logs.${RESET}"
    else
      response=$(curl -s localhost:9200/_plugins/_ml/tasks/$task_id)
      model_id=$(echo "$response" | jq -r '.model_id')
      echo -e "${MAJOR}Task completed successfully! Model deployed with id: $model_id${RESET}"
    fi
fi

echo -e "${MAJOR}Creating an ingest pipeline for embedding generation during index time.${RESET}"
curl -s -X PUT "http://localhost:9200/_ingest/pipeline/embeddings-pipeline" \
  -H 'Content-Type: application/json' \
  --data-binary "{
     \"description\": \"A text embedding pipeline\",
       \"processors\": [
         {
          \"set\": {
            \"field\": \"combined_field\",
            \"value\": \"{{title}} {{tagline}} {{overview}}\"
          }
         },
         {
          \"text_embedding\": {
          \"model_id\": \"$model_id\",
          \"field_map\": {
            \"combined_field\": \"movie_embedding\"
          }
        }
      }
    ]
  }"

curl -XPUT "http://localhost:9200/tmdb/" -H 'Content-Type: application/json' --data-binary @schema.json;

curl -s -X POST "http://localhost:9200/tmdb/_bulk?pretty=false&pipeline=embeddings-pipeline" -H 'Content-Type: application/json' --data-binary @tmdb_es.json;