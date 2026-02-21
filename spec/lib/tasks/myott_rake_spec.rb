RSpec.describe 'myott:send_watchlist_survey' do # rubocop:disable RSpec/DescribeClass
  subject(:send_watchlist_survey) { Rake::Task['myott:send_watchlist_survey'].invoke }

  let!(:user_with_stop_press_subscription) { create(:public_user, :with_active_stop_press_subscription) }
  let!(:user_with_my_commodities_subscription) { create(:public_user, :with_my_commodities_subscription) }
  let!(:user_with_both_subscriptions) do
    create(:public_user, :with_active_stop_press_subscription, :with_my_commodities_subscription)
  end
  let!(:user_without_subscription) { create(:public_user) }

  after do
    Rake::Task['myott:send_watchlist_survey'].reenable
  end

  it 'enqueues users with either subscription, excludes users without subscriptions, and does not duplicate users with both subscriptions' do
    allow(WatchListInvitationEmailWorker).to receive(:perform_async)

    send_watchlist_survey

    expect(WatchListInvitationEmailWorker).to have_received(:perform_async).with(user_with_stop_press_subscription.id).once
    expect(WatchListInvitationEmailWorker).to have_received(:perform_async).with(user_with_my_commodities_subscription.id).once
    expect(WatchListInvitationEmailWorker).to have_received(:perform_async).with(user_with_both_subscriptions.id).once
    expect(WatchListInvitationEmailWorker).not_to have_received(:perform_async).with(user_without_subscription.id)
  end
end
