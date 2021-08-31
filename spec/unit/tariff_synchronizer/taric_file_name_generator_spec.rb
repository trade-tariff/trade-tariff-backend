describe TariffSynchronizer::TaricFileNameGenerator do
  let(:example_date) { Date.new(2010, 1, 1) }
  let(:name_generator) { TariffSynchronizer::TaricFileNameGenerator.new(example_date) }

  describe '#url' do
    it 'returns the expected url to have the taric file for a specific date' do
      expect(name_generator.url).to eq('http://example.com/taric/TARIC320100101')
    end
  end

  describe '#get_info_from_response' do
    it 'returns an array containing a hash with filename and url' do
      result = name_generator.get_info_from_response('XYZ.xml')
      expect(result[0][:filename]).to eq('2010-01-01_XYZ.xml')
      expect(result[0][:url]).to eq('http://example.com/taric/XYZ.xml')
    end

    it 'returns an array containing multiple hashes if return multiple files' do
      result = name_generator.get_info_from_response("ABC.xml\nXYZ.xml")
      expect(result[0][:filename]).to eq('2010-01-01_ABC.xml')
      expect(result[0][:url]).to eq('http://example.com/taric/ABC.xml')
      expect(result[1][:filename]).to eq('2010-01-01_XYZ.xml')
      expect(result[1][:url]).to eq('http://example.com/taric/XYZ.xml')
    end
  end
end
