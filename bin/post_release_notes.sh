#!/bin/bash

webhook_url="$SLACK_WEBHOOK"
channel="#$SLACK_CHANNEL"
username="$SLACK_USERNAME"
message=$(bash bin/generate_release_notes.sh)
payload="{
  \"channel\": \"$channel\",
  \"text\": \"$message\",
  \"username\": \"$username\",
  \"mrkdwn\": true
}"

curl -X POST -H "Content-type: application/json" --data "$payload" "$webhook_url"
