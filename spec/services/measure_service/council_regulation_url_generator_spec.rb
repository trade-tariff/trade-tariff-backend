RSpec.describe MeasureService::CouncilRegulationUrlGenerator do
  let(:target_regulation) { create(:measure_partial_temporary_stop) }
  let(:service) { described_class.new(target_regulation) }

  describe '#generate' do
    it 'returns external regulation url' do
      expect(service.generate).to start_with('http://eur-lex.europa.eu/search.html')
    end
  end

  describe '#regulation_id' do
    context 'for measure_partial_temporary_stop' do
      it 'return regulation_id for target regulation' do
        expect(service.send(:regulation_id)).to eq(target_regulation.partial_temporary_stop_regulation_id)
      end
    end

    context 'for full_temporary_stop_regulation' do
      let(:target_regulation) { create(:fts_regulation) }

      it 'return regulation_id for target regulation' do
        expect(service.send(:regulation_id)).to eq(target_regulation.full_temporary_stop_regulation_id)
      end
    end

    context 'for base_regulation' do
      let(:target_regulation) { create(:base_regulation) }

      it 'return regulation_id for target regulation' do
        expect(service.send(:regulation_id)).to eq(target_regulation.base_regulation_id)
      end
    end
  end
end
