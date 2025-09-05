RSpec.describe Api::User::PublicUserSerializer do
  subject(:serialized) { described_class.new(serializable).serializable_hash }

  let(:serializable) { create(:public_user, email: 'oliver@email.com') }

  let(:expected) do
    {
      data: {
        id: serializable.external_id.to_s,
        type: :user,
        attributes: {
          chapter_ids: '01,99',
          email: 'oliver@email.com',
          stop_press_subscription: false,
          commodity_delta_subscription: false,
          commodity_codes: '1234567890, 1234567891',
        },
      },
    }
  end

  describe '#serializable_hash' do
    before do
      serializable.preferences.update(chapter_ids: '01,99')
      serializable.add_delta_preference(PublicUsers::DeltaPreferences.new(commodity_code: '1234567890'))
      serializable.add_delta_preference(PublicUsers::DeltaPreferences.new(commodity_code: '1234567891'))
    end

    it { expect(serialized).to eq(expected) }
  end
end
