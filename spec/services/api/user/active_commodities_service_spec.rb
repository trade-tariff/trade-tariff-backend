RSpec.describe Api::User::ActiveCommoditiesService do
  subject(:service) { described_class.new(original_codes) }

  let(:original_codes) { %w[1234567890 1234567891 1234567892 1234567893 1234567894 1234567895 1234567896] }

  let(:expected_active_codes) { %w[1234567890] }
  let(:expected_expired_codes) { %w[1234567891 1234567896] }
  let(:expected_erroneous_codes) { %w[1234567892 1234567893 1234567894 1234567895] }

  describe '#call' do
    before do
      TradeTariffRequest.time_machine_now = Time.current
      create(:commodity, :actual, goods_nomenclature_item_id: '1234567890')
      create(:commodity, :expired, goods_nomenclature_item_id: '1234567891')
      create(:commodity, :actual, :non_declarable, goods_nomenclature_item_id: '1234567894')
      create(:subheading, :actual, goods_nomenclature_item_id: '1234567895')
      create(:subheading, :expired, :with_children, goods_nomenclature_item_id: '1234567896')
    end

    let(:expected_result) do
      {
        active: expected_active_codes,
        expired: expected_expired_codes,
        erroneous: expected_erroneous_codes,
      }
    end

    it 'returns expected result' do
      expect(service.call).to eq(expected_result)
    end
  end
end
