RSpec.describe PublicUsers::ActionLog do
  subject(:action_log) { described_class.new(user: user) }

  let(:user) { create(:public_user) }

  describe 'associations' do
    it 'has a user association' do
      t = described_class.association_reflections[:user]
      expect(t[:type]).to eq(:many_to_one)
    end
  end

  context 'when action is allowed' do
    PublicUsers::ActionLog::ALLOWED_ACTIONS.each do |valid_action|
      it "is valid for action '#{valid_action}'" do
        action_log.action = valid_action
        action_log.valid?
        expect(action_log.errors).to be_empty
      end
    end
  end

  context 'when action is not allowed' do
    let(:action) { 'invalid_action' }

    it 'is not valid' do
      action_log.valid?
      expect(action_log.errors[:action]).to include('is not valid')
    end
  end
end
