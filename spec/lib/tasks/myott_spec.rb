# rubocop:disable RSpec/DescribeClass
RSpec.describe 'myott:send_reminder_watchlist_invitations' do
  subject(:send_reminders) do
    suppress_output { Rake::Task['myott:send_reminder_watchlist_invitations'].invoke }
  end

  let!(:subscribed_user) { create(:public_user, :with_active_stop_press_subscription) }
  let!(:unsubscribed_user) { create(:public_user, :with_active_stop_press_subscription) }
  let!(:user_without_stop_press) { create(:public_user) }

  before do
    allow(WatchListInvitationEmailWorker).to receive(:perform_async)
    PublicUsers::ActionLog.create(
      user_id: subscribed_user.id,
      action: PublicUsers::ActionLog::SUBSCRIBED_MY_COMMODITIES,
    )
    user_without_stop_press
  end

  after do
    Rake::Task['myott:send_reminder_watchlist_invitations'].reenable
  end

  it 'queues invitations only for users without my commodities subscription logs' do
    send_reminders

    expect(WatchListInvitationEmailWorker).to have_received(:perform_async).with(unsubscribed_user.id)
    expect(WatchListInvitationEmailWorker).not_to have_received(:perform_async).with(subscribed_user.id)
  end
end
# rubocop:enable RSpec/DescribeClass
