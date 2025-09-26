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
          erroneous_commodity_codes: %w[1234567890 1234567891],
          active_commodity_codes: %w[1111111111 2222222222],
          expired_commodity_codes: %w[3333333333 4444444444],
        },
      },
    }
  end

  describe '#serializable_hash' do
    before do
      serializable.preferences.update(chapter_ids: '01,99')
      serializable.add_delta_preference(PublicUsers::DeltaPreferences.new(commodity_code: '1234567890'))
      serializable.add_delta_preference(PublicUsers::DeltaPreferences.new(commodity_code: '1234567891'))
      serializable.add_delta_preference(PublicUsers::DeltaPreferences.new(commodity_code: '1111111111'))
      serializable.add_delta_preference(PublicUsers::DeltaPreferences.new(commodity_code: '2222222222'))
      serializable.add_delta_preference(PublicUsers::DeltaPreferences.new(commodity_code: '3333333333'))
      serializable.add_delta_preference(PublicUsers::DeltaPreferences.new(commodity_code: '4444444444'))
      create(:commodity, :actual, goods_nomenclature_item_id: '1111111111')
      create(:commodity, :actual, goods_nomenclature_item_id: '2222222222')
      create(:commodity, :expired, goods_nomenclature_item_id: '3333333333')
      create(:commodity, :expired, goods_nomenclature_item_id: '4444444444')
    end

    it { expect(serialized).to eq(expected) }
  end
end
