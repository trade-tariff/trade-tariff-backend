RSpec.describe AdditionalCodeSearchService do
  describe '#call' do
    subject(:result) { described_class.new(search_attributes, current_page, per_page).call }

    let!(:additional_code) { create(:additional_code, :with_description, additional_code_description: 'Test description') }

    let(:current_page) { 1 }
    let(:per_page) { 20 }

    before do
      current_goods_nomenclature = create(:heading)

      create(
        :measure,
        :with_base_regulation,
        additional_code:,
        goods_nomenclature: current_goods_nomenclature,
      )
      create(
        :goods_nomenclature_description,
        goods_nomenclature_sid: current_goods_nomenclature.goods_nomenclature_sid,
      )
      create(
        :measure,
        :with_base_regulation,
        additional_code_sid: additional_code.additional_code_sid,
        goods_nomenclature_sid: nil,
        goods_nomenclature_item_id: nil,
      )
      create(
        :additional_code_description,
        :with_period,
        additional_code_sid: additional_code.additional_code_sid,
      )

      Sidekiq::Testing.inline! do
        TradeTariffBackend.cache_client.reindex(Cache::AdditionalCodeIndex.new)
        sleep(1)
      end
    end

    context 'when searching by additional code with 4 digits' do
      let(:search_attributes) { { 'code' => "#{additional_code.additional_code_type_id}#{additional_code.additional_code}" } }

      it 'returns current matching additional codes' do
        expect(result.map(&:additional_code_sid)).to eq([additional_code.additional_code_sid])
      end
    end

    context 'when searching by additional code with 3 digits' do
      let(:search_attributes) { { 'code' => additional_code.additional_code } }

      it 'returns current matching additional codes' do
        expect(result.map(&:additional_code_sid)).to eq([additional_code.additional_code_sid])
      end
    end

    context 'when searching by additional code type' do
      let(:search_attributes) { { 'type' => additional_code.additional_code_type_id } }

      it 'returns current matching additional codes' do
        expect(result.map(&:additional_code_sid)).to eq([additional_code.additional_code_sid])
      end
    end

    context 'when searching by additional code description' do
      let(:search_attributes) { { 'description' => additional_code.description } }

      it 'returns current matching additional codes' do
        expect(result.map(&:additional_code_sid)).to eq([additional_code.additional_code_sid])
      end
    end

    context 'when searching by additional code description prefix' do
      let(:search_attributes) { { 'description' => 'Test' } }

      it 'returns current matching additional codes' do
        expect(result.map(&:additional_code_sid)).to eq([additional_code.additional_code_sid])
      end
    end
  end
end
