RSpec.describe Api::V2::MeasureSerializer do
  subject(:serializer) { described_class.new(serializable, options).serializable_hash.as_json }

  let(:serializable) { Api::V2::Measures::MeasurePresenter.new(measure.reload, measure.goods_nomenclature.reload) }

  let(:measure) { create(:measure, :with_measure_type, :with_meursing, :with_measure_components, :with_goods_nomenclature, reduction_indicator: 1) }
  let(:options) { {} }

  let(:expected_pattern) do
    {
      data: {
        id: '1',

        attributes: {
          effective_end_date: nil,
          effective_start_date: '2019-11-02T00:00:00.000Z',
          excise: false,
          export: true,
          import: true,
          origin: 'eu',
          vat: false,
        },
        relationships: {
          additional_code: { data: nil },
          duty_expression: {
            data: {
              id: '1-duty_expression', type: 'duty_expression'
            },
          },
          excluded_geographical_areas: { data: [] },
          footnotes: { data: [] },
          geographical_area: {
            data: { id: '1', type: 'geographical_area' },
          },
          goods_nomenclature: { data: { id: '1', type: 'commodity' } },
          legal_acts: { data: [] },
          measure_components: { data: [{ id: '1-12', type: 'measure_component' }] },
          measure_conditions: { data: [] },
          measure_type: { data: { id: '10000', type: 'measure_type' } },
          order_number: { data: nil },
        },
        type: 'measure',
      },
    }.as_json
  end

  describe '#serializable_hash' do
    it { is_expected.to include_json(expected_pattern) }
    # it { is_expected.to equal(expected_pattern) }
  end
end
