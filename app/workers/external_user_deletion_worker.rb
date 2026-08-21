# frozen_string_literal: true

class ExternalUserDeletionWorker
  include Sidekiq::Worker

  # External Identity API calls; cap retries vs Sidekiq default (25).
  sidekiq_options retry: 3

  def perform(user_id)
    user = PublicUsers::User[user_id]
    return unless user&.deleted

    if user.external_id
      # Check for another active user with the same external_id
      active_user = PublicUsers::User.active.where(external_id: user.external_id).exclude(id: user.id).first
      if active_user
        user.update(external_id: nil)
        return
      end

      if IdentityApiClient.delete_user(user.external_id)
        user.update(external_id: nil)
      end
    end
  end
end
