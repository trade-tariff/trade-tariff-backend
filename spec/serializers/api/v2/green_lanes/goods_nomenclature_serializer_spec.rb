RSpec.describe Api::V2::GreenLanes::GoodsNomenclatureSerializer do
  subject(:serialized) do
    described_class.new(gn_presenter, include: %w[applicable_measures possible_categorisations]).serializable_hash
  end

  let(:gn_presenter) { Api::V2::GreenLanes::GoodsNomenclaturePresenter.new(subheading, categorisations) }

  let(:subheading) { create :subheading, :with_measures }

  let(:categorisations) { GreenLanes::Categorisation.load_from_string(json_string) }

  let(:json_string) do
    '[{
          "category": "1",
          "regulation_id": "D0000001",
          "measure_type_id": "400",
          "geographical_area": "1000",
          "document_codes": [],
          "additional_codes": []
        }]'
  end

  let(:expected_pattern) do
    {
      data: {
        attributes: {
          goods_nomenclature_item_id: subheading.goods_nomenclature_item_id.to_s,
          goods_nomenclature_sid: subheading.goods_nomenclature_sid,
          description: be_a(String),
          formatted_description: subheading.formatted_description,
          validity_start_date: subheading.validity_start_date.iso8601,
          validity_end_date: nil,
          description_plain: subheading.description_plain,
          producline_suffix: subheading.producline_suffix,
        },
        "relationships": {
          "applicable_measures": {
            "data": [{
              "id": subheading.applicable_measures.first.id.to_s,
              type: eq(:measure),
            }],
          },
          "possible_categorisations": {
            "data": [{
              "id": GreenLanes::Categorisation.all[0].id,
              type: eq(:green_lanes_categorisation),
            }],
          },
        },
      },
      included: [{
        id: subheading.applicable_measures.first.id.to_s,
        type: eq(:measure),
      },
                 {
                   id: GreenLanes::Categorisation.all[0].id,
                   type: eq(:green_lanes_categorisation),
                 }],
    }
  end

  it { is_expected.to include_json(expected_pattern) }
end
