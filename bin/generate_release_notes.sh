#!/usr/bin/env bash

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

  # Check if there are any merge commits
  if ! git log --merges HEAD...$sha1 --format="format:- %b" --grep 'Merge pull request' | grep -q .; then
    # If there are no merge commits, change back to the parent directory and return
    cd ..
    return
  fi

  # Change to the specified repository or exit if unable to do so
  cd "$repo" || exit

  # Print the name of the repository
	echo
  echo "*$repo*"
  echo

  # Print the SHA-1 hash
  echo "_${sha1}_"
  echo

  # Print the merge logs
  git --no-pager log --merges HEAD...$sha1 --format="format:- %b" --grep 'Merge pull request'
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

