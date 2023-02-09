
#!/bin/bash

# Get the SLACK_WEBHOOK and SLACK_CHANNEL environment variables
webhook_url="$SLACK_WEBHOOK"
channel="#$SLACK_CHANNEL"
username="$SLACK_USERNAME"

# Get the output of the release notes script
message=$(bash bin/generate_release_notes.sh)

# Define the message payload in JSON format
payload="{
  \"channel\": \"$channel\",
  \"text\": \"$message\",
  \"username\": \"$username\",
  \"mrkdwn\": false
}"

# Use cURL to send the message to the Slack API
curl -X POST -H "Content-type: application/json" --data "$payload" "$webhook_url"
