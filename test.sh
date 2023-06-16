#!/bin/bash

# POST request to enqueue a job and extract the job ID
job_id=$(curl -s -X POST "http://localhost:3000/bulk_searches" -d @body.json -H 'Content-Type: application/json' -H 'Accept: application/json' | jq -r '.data.id')

echo "Job ID: $job_id"
# Continually poll the status of the job until it's completed
while true; do
    # GET request to check the status of the job
    response=$(curl -s "http://localhost:3000/bulk_searches/${job_id}" -H 'Content-Type: application/json' -H 'Accept: application/json' -w "\n%{http_code}\n")
    body=$(echo "$response" | head -n -1)
    status=$(echo "$response" | tail -n 1)
    job_status=$(echo $body | jq -r '.data.attributes.status')
    # Extract the status from the response
    echo "Status: $job_status ($status)"

    # Check if the status is "complete" or "error or "not_found"
    if [ "$status" = "200" ]; then
        # Output the completed job's response and break the loop
        echo "$body" | jq
        break
    else
        # Sleep for a while before checking again
        sleep 0.5
    fi
done
