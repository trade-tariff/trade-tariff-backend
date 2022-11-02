RSpec.describe Api::V2::MeasureSerializer do
  subject(:serializer) { described_class.new(serializable, options).serializable_hash.as_json }

  let(:serializable) { Api::V2::Measures::MeasurePresenter.new(measure.reload, measure.goods_nomenclature.reload) }

  let(:measure) do create(:measure,
                         :with_measure_type,
                         :with_measure_components,
                         :with_goods_nomenclature,
                         :with_measure_conditions
                         )
  end

  let(:options) { {} }

  let(:expected_pattern) do
    {
      data: {
        id: measure.measure_sid.to_s,
        type: 'measure',
        attributes: {
          effective_end_date: nil,
          effective_start_date: "2019-11-02T00:00:00.000Z",
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
              id: "#{measure.id}-duty_expression",
            },
          },
          excluded_geographical_areas: { data: [] },
          footnotes: { data: [] },
          geographical_area: {
            data: { id: '1', type: 'geographical_area' },
          },
          goods_nomenclature: { data: { id: '1', type: 'commodity' } },
          legal_acts: { data: [] },
          measure_components: { data: [{ id: measure.measure_components.first.pk.join('-'), type: 'measure_component' }] },
          measure_conditions: {data: [{id: '1', type: "measure_condition"}]},
          measure_type: {
            data: {
              id: measure.measure_type_id,
              type: 'measure_type',
            },
          },
          order_number: { data: nil },
        },
      },
    }.as_json
  end

  describe '#serializable_hash' do
    it { is_expected.to include_json(expected_pattern) }
  end
end
