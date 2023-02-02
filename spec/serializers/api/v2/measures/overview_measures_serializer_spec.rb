RSpec.describe Api::V2::Measures::OverviewMeasureSerializer do
  subject(:serializable_hash) { described_class.new(serializable).serializable_hash.as_json }

  let(:serializable) do
    measure
    mashed_heading = Hashie::TariffMash.new(Cache::HeadingSerializer.new(commodity.heading).as_json)
    mashed_heading.commodities.first.overview_measures.first
  end

  let(:commodity) { create(:commodity, :with_heading) }

  let(:measure) do
    create(
      :measure,
      :third_country_overview,
      :with_additional_code,
      :with_measure_components,
      :with_base_regulation,
      :with_measure_type,
      goods_nomenclature_sid: commodity.goods_nomenclature_sid,
    )
  end

  let(:expected_pattern) do
    {
      'data' => {
        'id' => match(/\d+/),
        'type' => 'measure',
        'attributes' => {
          'id' => be_a(Integer),
          'vat' => false,
        },
        'relationships' => {
          'duty_expression' => {
            'data' => {
              'id' => /\d+-duty_expression/,
              'type' => 'duty_expression',
            },
          },
          'measure_type' => {
            'data' => {
              'id' => match(/\d{3}/),
              'type' => 'measure_type',
            },
          },
          'additional_code' => {
            'data' => {
              'id' => match(/\d+/),
              'type' => 'additional_code',
            },
          },
        },
      },
    }
  end

  describe '#serializable_hash' do
    it { is_expected.to include_json(expected_pattern) }
  end
end
