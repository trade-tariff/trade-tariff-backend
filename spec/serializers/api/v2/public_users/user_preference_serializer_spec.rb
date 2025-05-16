RSpec.describe Api::V2::PublicUsers::UserPreferenceSerializer do
  subject(:serialized) do
    described_class.new(user_preference).serializable_hash
  end

  # let(:user) { create :public_users_user }
  let(:user_preference) { create :public_users_user_preference }

  let :expected do
    {
      data: {
        id: user_preference.id.to_s,
        type: :user_preference,
        attributes: {
          user_id: user_preference.user_id,
          chapter_ids: user_preference.chapter_ids,
        },
      },
    }
  end

  describe '#serializable_hash' do
    it 'matches the expected hash' do
      expect(serialized).to eq(expected)
    end
  end
end
