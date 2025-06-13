require 'rails_helper'

RSpec.describe RemoveFailedSubscribersWorker, type: :worker do
  let(:user) { create(:public_user) }

  before do
    allow(user).to receive(:soft_delete!)
    allow(PublicUsers::User).to receive(:failed_subscribers).and_return([user])
  end

  it 'calls soft_delete! on all failed subscribers' do
    described_class.new.perform
    expect(user).to have_received(:soft_delete!)
  end

  it 'creates an action log for each user', :aggregate_failures do
    expect {
      described_class.new.perform
    }.to change(PublicUsers::ActionLog, :count).by(1)

    action_log = PublicUsers::ActionLog.last
    expect(action_log.user_id).to eq(user.id)
    expect(action_log.action).to eq(PublicUsers::ActionLog::FAILED_SUBSCRIBER)
  end
end
