RSpec.describe Api::V2::Subheadings::SubheadingSerializer do
  subject(:serializer) { described_class.new(serializable).serializable_hash.as_json }

  let(:serializable) do
    path = Rails.root.join(file_fixture_path, 'cached_subheading_exhaustive_annotated.json')
    file = File.read(path)
    file = JSON.parse(file)

    Hashie::TariffMash.new(file)
  end

  let(:expected_pattern) do
    {
      'data' => {
        'id' => '93798',
        'type' => 'subheading',
        'attributes' => {
          'goods_nomenclature_item_id' => '0101290000',
          'goods_nomenclature_sid' => 93_798,
          'number_indents' => 2,
          'producline_suffix' => '80',
          'description' => 'Other',
          'formatted_description' => 'Other',
          'declarable' => false,
        },
        'relationships' => {
          'section' => { 'data' => { 'id' => '1', 'type' => 'section' } },
          'chapter' => { 'data' => { 'id' => '27623', 'type' => 'chapter' } },
          'heading' => { 'data' => { 'id' => '27624', 'type' => 'heading' } },
          'commodities' => { 'data' => [{ 'id' => '93797', 'type' => 'commodity' }, { 'id' => '93798', 'type' => 'commodity' }, { 'id' => '93799', 'type' => 'commodity' }, { 'id' => '93800', 'type' => 'commodity' }] },
          'footnotes' => { 'data' => [] },
        },
      },
    }
  end

  describe '#serializable_hash' do
    it { is_expected.to include_json(expected_pattern) }
  end
end
