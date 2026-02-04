namespace :myott do
  desc 'Send watch list invitation emails to users with active stop press subscriptions'
  task send_watchlist_invitations: %w[environment] do
    PublicUsers::User.with_active_stop_press_subscription.each do |user|
      WatchListInvitationEmailWorker.perform_async(user.id)
    end
  end
end
