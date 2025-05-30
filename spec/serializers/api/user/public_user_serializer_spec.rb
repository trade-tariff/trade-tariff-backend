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
        },
      },
    }
  end

  describe '#serializable_hash' do
    before do
      serializable.preferences.update(chapter_ids: '01,99')
    end

    it { expect(serialized).to eq(expected) }
  end
end
