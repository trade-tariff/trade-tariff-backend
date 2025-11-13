RSpec.describe Api::User::ActiveCommoditiesService do
  subject(:service) { described_class.new(subscription) }

  let(:target_ids) { [123, 456, 789, 321, 654] }
  let(:commodity_codes) { %w[1234567890 1234567891 1234567892 1234567893 1234567894] }
  let(:subscription) { create(:user_subscription, metadata: { commodity_codes: commodity_codes }) }

  let(:expected_active_codes) { %w[1234567890] }
  let(:expected_expired_codes) { %w[1234567891 1234567894] }
  let(:expected_invalid_codes) { %w[1234567892 1234567893] }

  before do
    TradeTariffRequest.time_machine_now = Time.current

    target_ids.each do |target_id|
      create(:subscription_target,
             user_subscriptions_uuid: subscription.uuid,
             target_id: target_id,
             target_type: 'commodity')
    end

    create(:commodity, :actual, goods_nomenclature_item_id: '1234567890', goods_nomenclature_sid: 123)
    create(:commodity, :expired, goods_nomenclature_item_id: '1234567891', goods_nomenclature_sid: 456)
    create(:subheading, :expired, :with_children, goods_nomenclature_item_id: '1234567894', goods_nomenclature_sid: 654)
  end

  describe '#call' do
    let(:expected_result) do
      {
        active: expected_active_codes,
        expired: expected_expired_codes,
        invalid: expected_invalid_codes,
      }
    end

    it 'returns expected result' do
      expect(service.call).to eq(expected_result)
    end
  end

  describe 'paginated commodity loaders' do
    it 'returns paginated active commodities with correct total' do
      commodities, total = service.active_commodities(page: 1, per_page: 10)
      expect(total).to eq(1)
      expect(commodities.map(&:goods_nomenclature_item_id)).to eq(expected_active_codes)
    end

    it 'returns paginated expired commodities with correct total' do
      commodities, total = service.expired_commodities(page: 1, per_page: 10)
      expect(total).to eq(2)
      expect(commodities.map(&:goods_nomenclature_item_id)).to eq(expected_expired_codes)
    end

    it 'returns paginated invalid commodities with correct total' do
      commodities, total = service.invalid_commodities(page: 1, per_page: 10)
      expect(total).to eq(2)
      expect(commodities.map(&:goods_nomenclature_item_id)).to eq(expected_invalid_codes)
    end
  end
end
