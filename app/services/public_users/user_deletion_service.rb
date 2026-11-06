module PublicUsers
  # Soft deleting a user also has to delete the user in the identity provider.
  # The models only change our own data and say whether they deleted the user.
  # This service starts the external deletion, so callers cannot forget it.
  class UserDeletionService
    class << self
      def soft_delete(user)
        schedule_external_deletion(user) if user.soft_delete!
      end

      def invalidate(user)
        schedule_external_deletion(user) if user.invalidate!
      end

      def unsubscribe(subscription)
        schedule_external_deletion(subscription.user) if subscription.unsubscribe
      end

    private

      def schedule_external_deletion(user)
        ExternalUserDeletionWorker.perform_async(user.id)
      end
    end
  end
end
