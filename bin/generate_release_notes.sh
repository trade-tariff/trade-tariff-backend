#!/usr/bin/env bash

set -o errexit
set -o nounset

if [ -d "repos" ]; then
  rm -rf repos
fi

# Create a directory to store the repositories
mkdir repos

# Change to the newly created directory or exit if unable to do so
cd repos || exit

# Clone the specified repositories
git clone --quiet --depth 100 https://github.com/trade-tariff/trade-tariff-frontend.git
git clone --quiet --depth 100 https://github.com/trade-tariff/trade-tariff-backend.git
git clone --quiet --depth 100 https://github.com/trade-tariff/trade-tariff-duty-calculator.git
git clone --quiet --depth 100 https://github.com/trade-tariff/trade-tariff-admin.git
git clone --quiet --depth 100 https://github.com/trade-tariff/trade-tariff-search-query-parser.git

# Log function to print the logs for a repository
log_for() {
  local url=$1
  local repo=$2
  local sha1=""

  # Retrieve the SHA-1 hash from the specified URL
  sha1=$(curl --silent "$url" | jq '.git_sha1' | tr -d '"')

  # Change to the specified repository or exit if unable to do so
  cd "$repo" || exit

  # Print the name of the repository
  echo
  echo "*$repo*"
  echo

  # Print the SHA-1 hash
  echo "_<https://github.com/trade-tariff/$repo/commit/$sha1|${sha1}>_"
  echo

  # Check if there are merge commits in the specified range
  merge_commits=$(git rev-list HEAD...$sha1 --merges)
  if [ -n "$merge_commits" ]; then
    # Print the merge logs
    while read -r line; do
      message=$(echo "$line" | awk -F\| '{print $1}')
      subject_line=$(echo "$line" | awk -F\| '{print $2}')
      # Extract the pull request number from the commit message
      pr_number=$(echo "$subject_line" | sed 's/^Merge pull request #\([0-9]*\).*$/\1/g')
      # Construct the link to the pull request
      pr_link="https://github.com/trade-tariff/${repo}/pull/${pr_number}"
      # Replace the commit message with a markdown link to the pull request
      echo "* <${pr_link}|${message}>"
    done <<< "$(git --no-pager log --merges HEAD...$sha1 --format="format:%b|%s" --grep 'Merge pull request')"
  else
    # Print a message indicating that there are no merge commits
    echo "Nothing to release."
    echo
  fi
  echo

  # Change back to the parent directory
  cd ..
}

# Function to print the logs for all repositories
all_logs() {
  log_for "https://www.trade-tariff.service.gov.uk/healthcheck" "trade-tariff-frontend"
  log_for "https://www.trade-tariff.service.gov.uk/api/v2/healthcheck" "trade-tariff-backend"
  log_for "https://www.trade-tariff.service.gov.uk/duty-calculator/healthcheck" "trade-tariff-duty-calculator"
  log_for "https://tariff-admin-production.london.cloudapps.digital/healthcheck" "trade-tariff-admin"
  log_for "https://www.trade-tariff.service.gov.uk/api/search/healthcheck" "trade-tariff-search-query-parser"
}

all_logs

# Clear repos directory if script ran locally and we need to rerun
rm -rf repos
