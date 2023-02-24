RSpec.describe Api::V2::Subheadings::SubheadingSerializer do
  subject(:serializable_hash) { described_class.new(serializable, options).serializable_hash.as_json }

  let(:options) do
    includes = [
      'commodities.overview_measures.additional_code',
    ]

    { include: includes }
  end

  let(:serializable) do
    path = Rails.root.join(file_fixture_path, 'cached_subheading_exhaustive_annotated.json')
    file = File.read(path)
    file = JSON.parse(file)

    Hashie::TariffMash.new(file)
  end

  let(:expected_pattern) do
    {
      'data' => {
        'id' => '35834',
        'type' => 'subheading',
        'attributes' => { 'goods_nomenclature_item_id' => '2818300000', 'goods_nomenclature_sid' => 35_834, 'number_indents' => 1, 'producline_suffix' => '80', 'description' => 'Aluminium hydroxide', 'formatted_description' => 'Aluminium hydroxide', 'validity_start_date' => '1972-01-01T00:00:00.000Z', 'validity_end_date' => nil, 'declarable' => false },
        'relationships' => {
          'section' => { 'data' => { 'id' => '6', 'type' => 'section' } },
          'chapter' => { 'data' => { 'id' => '35719', 'type' => 'chapter' } },
          'heading' => { 'data' => { 'id' => '35831', 'type' => 'heading' } },
          'ancestors' => { 'data' => [] },
          'commodities' => {
            'data' => [
              { 'id' => '35834', 'type' => 'commodity' },
              { 'id' => '100107', 'type' => 'commodity' },
              { 'id' => '100483', 'type' => 'commodity' },
              { 'id' => '35836', 'type' => 'commodity' },
            ],
          },
          'footnotes' => { 'data' => [] },
        },
      },
    }
  end

  describe '#serializable_hash' do
    let(:additional_code_count) do
      serializable_hash['included'].select { |i|
        i['type'] == 'additional_code'
      }.count
    end

    it { is_expected.to include_json(expected_pattern) }

    it { expect(additional_code_count).to eq(2) }
  end
end
