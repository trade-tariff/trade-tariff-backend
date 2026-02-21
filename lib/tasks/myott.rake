namespace :myott do
  desc 'Send watch list survey emails to users with any active subscription'
  task send_watchlist_survey: %w[environment] do
    (PublicUsers::User.with_active_stop_press_subscription.all + PublicUsers::User.with_active_my_commodities_subscription.all).uniq.each do |user|
      WatchListInvitationEmailWorker.perform_async(user.id)
    end
  end
end
