RSpec.describe DistributionListRecipients do
  subject(:service) { described_class.new(client:, user_pool_id: 'eu-west-2_pool') }

  let(:client) { Aws::CognitoIdentityProvider::Client.new(stub_responses: true) }
  let(:error_log) { StringIO.new }
  let(:log) { StringIO.new }

  def user(email, enabled: true)
    attributes = email ? [{ name: 'email', value: email }] : []
    { username: SecureRandom.uuid, attributes:, enabled: }
  end

  before do
    allow(Rails.logger).to receive(:warn) { |message| log.puts(message) }
    allow(Rails.logger).to receive(:error) { |message| error_log.puts(message) }
  end

  describe '.valid_group_name?' do
    it 'accepts dl- groups and rejects role groups', :aggregate_failures do
      expect(described_class.valid_group_name?('dl-cds-updates')).to be(true)
      expect(%w[admin myott portal dl- DL-x dl_x].map { |name| described_class.valid_group_name?(name) }).to all(be(false))
    end
  end

  describe '.client' do
    it 'uses short timeouts so a slow Cognito falls back quickly', :aggregate_failures do
      config = described_class.client.config

      expect([config.http_open_timeout, config.http_read_timeout, config.max_attempts]).to eq([5, 10, 2])
    end
  end

  describe '#emails' do
    it 'returns the sorted, unique, lower-case emails of the enabled members' do
      client.stub_responses(:list_users_in_group, users: [user('b@example.com'), user(' A@example.com '), user('a@example.com'), user('off@example.com', enabled: false), user(nil)])

      expect(service.emails('dl-cds-updates')).to eq(%w[a@example.com b@example.com])
    end

    it 'reads every page', :aggregate_failures do
      client.stub_responses(:list_users_in_group, [{ users: [user('a@example.com')], next_token: 'next' }, { users: [user('b@example.com')] }])

      expect(service.emails('dl-cds-updates')).to eq(%w[a@example.com b@example.com])
      expect(client.api_requests.map { |request| request[:params][:next_token] }).to eq([nil, 'next'])
    end

    it 'asks Cognito for the group in the configured pool' do
      service.emails('dl-cds-updates')

      expect(client.api_requests.first[:params]).to include(user_pool_id: 'eu-west-2_pool', group_name: 'dl-cds-updates')
    end

    it 'returns nil and logs when the group is empty', :aggregate_failures do
      client.stub_responses(:list_users_in_group, users: [])

      expect(service.emails('dl-cds-updates')).to be_nil
      expect(log.string).to include('distribution_list.fallback group=dl-cds-updates reason=empty')
      expect(error_log.string).to be_empty
    end

    it 'returns nil without logging emails when Cognito fails', :aggregate_failures do
      client.stub_responses(:list_users_in_group, 'AccessDeniedException')

      expect(service.emails('dl-cds-updates')).to be_nil
      expect(error_log.string).to include('distribution_list.read_failed group=dl-cds-updates reason=AccessDeniedException')
    end

    it 'returns nil when Cognito times out' do
      client.stub_responses(:list_users_in_group, Seahorse::Client::NetworkingError.new(Net::ReadTimeout.new))

      expect(service.emails('dl-cds-updates')).to be_nil
    end

    it 'returns nil when the SDK has no credentials to sign with', :aggregate_failures do
      client.stub_responses(:list_users_in_group, Aws::Errors::MissingCredentialsError)

      expect(service.emails('dl-cds-updates')).to be_nil
      expect(error_log.string).to include('distribution_list.read_failed group=dl-cds-updates reason=MissingCredentialsError')
    end

    it 'returns nil when assuming a role for credentials fails' do
      client.stub_responses(:list_users_in_group, Aws::STS::Errors::AccessDenied.new(nil, 'denied'))

      expect(service.emails('dl-cds-updates')).to be_nil
    end

    it 'returns nil when the client cannot resolve its credentials', :aggregate_failures do
      allow(Aws::CognitoIdentityProvider::Client).to receive(:new).and_raise(Aws::Errors::NoSuchProfileError)

      expect(described_class.new(user_pool_id: 'eu-west-2_pool').emails('dl-cds-updates')).to be_nil
      expect(error_log.string).to include('reason=NoSuchProfileError')
    end

    it 'returns nil for any other AWS SDK error', :aggregate_failures do
      client.stub_responses(:list_users_in_group, Aws::Errors::InvalidSSOToken)

      expect(service.emails('dl-cds-updates')).to be_nil
      expect(error_log.string).to include('reason=InvalidSSOToken')
    end

    it 'raises errors that do not come from the AWS SDK' do
      client.stub_responses(:list_users_in_group, NoMethodError)

      expect { service.emails('dl-cds-updates') }.to raise_error(NoMethodError)
    end

    it 'returns nil without calling Cognito when no user pool is set', :aggregate_failures do
      expect(described_class.new(client:, user_pool_id: nil).emails('dl-cds-updates')).to be_nil
      expect(client.api_requests).to be_empty
    end

    it 'refuses a group that is not a distribution list' do
      expect { service.emails('admin') }.to raise_error(ArgumentError)
    end

    it 'never logs an email' do
      client.stub_responses(:list_users_in_group, [{ users: [user('a@example.com')], next_token: 'next' }, 'TooManyRequestsException'])
      service.emails('dl-cds-updates')

      expect("#{log.string}#{error_log.string}").not_to include('@')
    end
  end
end
