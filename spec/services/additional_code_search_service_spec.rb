RSpec.describe AdditionalCodeSearchService do
  describe 'additional code search' do
    around do |example|
      TimeMachine.now { example.run }
    end

    let!(:additional_code_1) { create :additional_code }
    let!(:additional_code_description_1) { create :additional_code_description, :with_period, additional_code_sid: additional_code_1.additional_code_sid }
    let!(:measure_1) { create :measure, additional_code_sid: additional_code_1.additional_code_sid }
    let!(:goods_nomenclature_1) { measure_1.goods_nomenclature }

    let!(:additional_code_2) { create :additional_code }
    let!(:additional_code_description_2) { create :additional_code_description, :with_period, additional_code_sid: additional_code_2.additional_code_sid }
    let!(:measure_2) { create :measure, additional_code_sid: additional_code_2.additional_code_sid }
    let!(:goods_nomenclature_2) { measure_2.goods_nomenclature }
    let(:current_page) { 1 }
    let(:per_page) { 20 }

    before do
      Sidekiq::Testing.inline! do
        TradeTariffBackend.cache_client.reindex
        sleep(1)
      end
    end

    context 'by additional code' do
      it 'finds additional code by code' do
        result = described_class.new({
          'code' => additional_code_1.additional_code,
        }, current_page, per_page).perform
        expect(result.map(&:additional_code_sid)).to include(additional_code_1.additional_code_sid)
      end

      it 'does not find additional code by wrong code' do
        result = described_class.new({
          'code' => additional_code_1.additional_code,
        }, current_page, per_page).perform
        expect(result.map(&:additional_code_sid)).not_to include(additional_code_2.additional_code_sid)
      end

      context 'when user enter 4-digits code' do
        it 'finds additional code by code' do
          result = described_class.new({
            'code' => "#{rand(9)}#{additional_code_1.additional_code}",
          }, current_page, per_page).perform
          expect(result.map(&:additional_code_sid)).to include(additional_code_1.additional_code_sid)
        end

        it 'ignores first digit' do
          service = described_class.new({
            'code' => "#{rand(9)}#{additional_code_1.additional_code}",
          }, current_page, per_page)
          service.perform
          expect(service.code).to eq(additional_code_1.additional_code)
        end
      end
    end

    context 'by additional code type' do
      it 'finds additional code by type' do
        result = described_class.new({
          'type' => additional_code_1.additional_code_type_id,
        }, current_page, per_page).perform
        expect(result.map(&:additional_code_sid)).to include(additional_code_1.additional_code_sid)
      end

      it 'does not find additional code by wrong code' do
        result = described_class.new({
          'type' => additional_code_1.additional_code_type_id,
        }, current_page, per_page).perform
        expect(result.map(&:additional_code_sid)).not_to include(additional_code_2.additional_code_sid)
      end
    end

    context 'by description' do
      it 'finds additional code by description' do
        result = described_class.new({
          'description' => additional_code_1.description,
        }, current_page, per_page).perform
        expect(result.map(&:additional_code_sid)).to include(additional_code_1.additional_code_sid)
      end

      it 'does not find additional code by wrong description' do
        result = described_class.new({
          'description' => additional_code_1.description,
        }, current_page, per_page).perform
        expect(result.map(&:additional_code_sid)).not_to include(additional_code_2.additional_code_sid)
      end
    end

    context 'by description first word' do
      it 'finds additional code by description first word' do
        result = described_class.new({
          'description' => additional_code_1.description.split(' ').first,
        }, current_page, per_page).perform
        expect(result.map(&:additional_code_sid)).to include(additional_code_1.additional_code_sid)
      end

      it 'does not find additional code by wrong description first word' do
        result = described_class.new({
          'description' => additional_code_1.description.split(' ').first,
        }, current_page, per_page).perform
        expect(result.map(&:additional_code_sid)).not_to include(additional_code_2.additional_code_sid)
      end
    end
  end
end
