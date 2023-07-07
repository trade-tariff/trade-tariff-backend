RSpec.describe BulkSearchDocumentBuilderService do
  describe '#call' do
    subject(:service) { described_class.new([goods_nomenclature], number_of_digits) }

    let(:goods_nomenclature) do
      create(
        :commodity,
        :with_description,
        :with_ancestors,
        goods_nomenclature_item_id: '0101210001',
        include_search_references: true,
        description: 'Horses',
      )
    end

    context 'when passing 6 digits' do
      let(:number_of_digits) { 6 }

      it 'returns a list of document objects that can be indexed by Opensearch' do
        expect(service.call).to include_json(
          [
            {
              'id' => '010121',
              'observed' => be_present,
              'number_of_digits' => 6,
              'short_code' => '010121',
              'indexed_descriptions' => match(['horses', 'live horses, asses, mules and hinnies', 'live animals']),
              'indexed_tradeset_descriptions' => match([]),
              'search_references' => match(['chapter search reference', 'heading search reference']),
              'intercept_terms' => be_empty,
            },
          ],
        )
      end
    end

    context 'when passing 8 digits' do
      let(:number_of_digits) { 8 }

      it 'returns a list of document objects that can be indexed by Opensearch' do
        expect(service.call).to include_json(
          [
            {
              'id' => '01012100',
              'observed' => be_present,
              'number_of_digits' => 8,
              'short_code' => '01012100',
              'indexed_descriptions' => match(['horses', 'live horses, asses, mules and hinnies', 'live animals']),
              'indexed_tradeset_descriptions' => match([]),
              'search_references' => match(['chapter search reference', 'heading search reference']),
              'intercept_terms' => be_empty,
            },
          ],
        )
      end
    end
  end
end
