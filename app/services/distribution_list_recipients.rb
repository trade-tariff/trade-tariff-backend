# Reads the recipients of an email distribution list from Cognito.
#
# A distribution list is a Cognito group named dl-<list> in the identity user
# pool. Technical operators manage the members in trade-tariff-admin. This is
# a read-only copy of the read path of admin's DistributionListService: keep
# GROUP_NAME_FORMAT and PROTECTED_GROUPS the same in both apps.
#
# Emails are read for sending only. Never write them to the database, the
# cache, the logs or an exception message.
class DistributionListRecipients
  GROUP_NAME_FORMAT = /\Adl-[a-z0-9][a-z0-9-]{0,120}\z/
  # Role/access groups. Distribution lists must never touch these.
  PROTECTED_GROUPS = %w[admin myott portal].freeze

  CLIENT_ERRORS = [
    Aws::CognitoIdentityProvider::Errors::ServiceError,
    Seahorse::Client::NetworkingError,
  ].freeze

  def self.valid_group_name?(name)
    name = name.to_s
    GROUP_NAME_FORMAT.match?(name) && PROTECTED_GROUPS.exclude?(name)
  end

  def self.client
    @client ||= Aws::CognitoIdentityProvider::Client.new(region: TradeTariffBackend.aws_region)
  end

  def initialize(client: nil, user_pool_id: TradeTariffBackend.cognito_user_pool_id)
    @client = client
    @user_pool_id = user_pool_id
  end

  # Returns the sorted, unique emails of the enabled members of the list, or
  # nil if the list is empty or cannot be read. On nil the caller uses its
  # fallback, so a Cognito failure does not stop the email.
  def emails(group_name)
    raise ArgumentError, 'Not a distribution list' unless self.class.valid_group_name?(group_name)
    return fallback(group_name, 'no_user_pool') if user_pool_id.blank?

    emails = paginate_users(group_name)
      .reject { |user| user.enabled == false }
      .filter_map { |user| email_of(user) }
      .uniq
      .sort

    emails.presence || fallback(group_name, 'empty')
  rescue *CLIENT_ERRORS => e
    fallback(group_name, e.class.name.demodulize)
  end

private

  attr_reader :user_pool_id

  def client
    @client || self.class.client
  end

  def paginate_users(group_name)
    users = []
    next_token = nil

    loop do
      response = client.list_users_in_group(user_pool_id:, group_name:, next_token:)
      users.concat(response.users)
      next_token = response.next_token
      break if next_token.blank?
    end

    users
  end

  def email_of(user)
    email = Array(user.attributes).find { |attribute| attribute.name == 'email' }&.value
    email&.strip&.downcase.presence
  end

  def fallback(group_name, reason)
    Rails.logger.warn("distribution_list.fallback group=#{group_name} reason=#{reason}")
    nil
  end
end
