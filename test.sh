#!/bin/bash

# POST request to enqueue a job and extract the job ID
job_id=$(curl --compressed -s -X POST "http://localhost:3000/bulk_search" -d @body.json -H 'Content-Type: application/json' -H 'Accept: application/json' -H 'Accept-Encoding: gzip' | jq -r '.data.id')

echo "Job ID: $job_id"
# Continually poll the status of the job until it's completed
while true; do
    # GET request to check the status of the job
    response=$(curl --compressed -s "http://localhost:3000/bulk_search/${job_id}" -H 'Content-Type: application/json' -H 'Accept: application/json' -H 'Accept-Encoding: gzip')

    # Extract the status from the response
    status=$(echo "$response" | jq -r '.data.attributes.status')

    echo "Status: $status"

    # Check if the status is "complete" or "error or "not_found"
    if [ "$status" = "completed" ] || [ "$status" = "error" ] || [ "$status" = "not_found" ]; then
        # Output the completed job's response and break the loop
        echo "$response" | jq -r '.included | .[] | select(.type == "search")'
        break
    else
        # Sleep for a while before checking again
        sleep 0.5
    fi
done
