namespace :myott do
  desc 'Send watch list research invitation emails to users with active my commodities subscriptions'
  task send_watchlist_research_invitations: %w[environment] do
    PublicUsers::User.with_active_my_commodities_subscription.each do |user|
      WatchListInvitationEmailWorker.perform_async(user.id)
    end
  end
end
