RSpec.describe Api::User::ActiveCommoditiesService do
  subject(:service) { described_class.new(commodity_codes, target_ids) }

  let(:target_ids) { [123, 456, 789, 321, 654] }
  let(:commodity_codes) { %w[1234567890 1234567891 1234567892 1234567893 1234567894 1234567895 1234567896] }

  let(:expected_active_codes) { %w[1234567890] }
  let(:expected_expired_codes) { %w[1234567891 1234567896] }
  let(:expected_moved_codes) { %w[1234567894 1234567895] }
  let(:expected_invalid_codes) { %w[1234567892 1234567893] }

  describe '#call' do
    before do
      TradeTariffRequest.time_machine_now = Time.current
      create(:commodity, :actual, goods_nomenclature_item_id: '1234567890', goods_nomenclature_sid: 123)
      create(:commodity, :expired, goods_nomenclature_item_id: '1234567891', goods_nomenclature_sid: 456)
      create(:commodity, :actual, :non_declarable, goods_nomenclature_item_id: '1234567894', goods_nomenclature_sid: 789)
      create(:subheading, :actual, goods_nomenclature_item_id: '1234567895', goods_nomenclature_sid: 321)
      create(:subheading, :expired, :with_children, goods_nomenclature_item_id: '1234567896', goods_nomenclature_sid: 654)
    end

    let(:expected_result) do
      {
        active: expected_active_codes,
        expired: expected_expired_codes,
        moved: expected_moved_codes,
        invalid: expected_invalid_codes,
      }
    end

    it 'returns expected result' do
      expect(service.call).to eq(expected_result)
    end
  end
end
