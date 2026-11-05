# Specs must never call Cognito. A stubbed ListUsersInGroup returns no users,
# so distribution lists fall back to their env vars unless a spec stubs them.
Aws.config[:cognitoidentityprovider] = { stub_responses: true }

RSpec.configure do |config|
  config.before do
    DistributionListRecipients.instance_variable_set(:@client, nil)
  end
end
