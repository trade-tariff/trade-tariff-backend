RSpec.describe MeasureService::CouncilRegulationUrlGenerator do
  let(:target_regulation) { create(:measure_partial_temporary_stop, partial_temporary_stop_regulation_id: 'A09CDEF') }
  let(:service) { described_class.new(target_regulation) }

  describe '#generate' do
    it 'returns external regulation url' do
      code = '32009ACDEF'
      expect(service.generate).to eq("https://eur-lex.europa.eu/legal-content/EN/TXT/?uri=CELEX%3A#{code}")
    end

    it 'handles years that are greater than 2071' do
      target_regulation.partial_temporary_stop_regulation_id = 'A72CDEF'
      code = '31972ACDEF'
      expect(service.generate).to eq("https://eur-lex.europa.eu/legal-content/EN/TXT/?uri=CELEX%3A#{code}")
    end
  end
end
