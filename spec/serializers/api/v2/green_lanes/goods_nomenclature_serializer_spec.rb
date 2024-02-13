RSpec.describe Api::V2::GreenLanes::GoodsNomenclatureSerializer do
  subject(:serialized) do
    described_class.new(gn_presenter, include: %w[applicable_category_assessments applicable_category_assessments.geographical_area]).serializable_hash
  end

  let(:gn_presenter) { Api::V2::GreenLanes::GoodsNomenclaturePresenter.new(subheading, categorisations) }
  let(:json_string) do
    '[{
          "category": "1",
          "regulation_id": "D0000001",
          "measure_type_id": "400",
          "geographical_area_id": "1000",
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
          "applicable_category_assessments": {
            "data": [{
              "id": GreenLanes::CategoryAssessment.all[0].id,
              type: eq(:green_lanes_category_assessment),
            }],
          },
        },
      },
      included: [
        {
          id: '1000',
          type: eq(:geographical_area),
        },
        {
          id: GreenLanes::CategoryAssessment.all[0].id,
          type: eq(:green_lanes_category_assessment),
        },
      ],
    }
  end

  let(:subheading) { create :subheading, :with_measures }

  let(:categorisations) { GreenLanes::CategoryAssessment.load_from_string(json_string) }

  before do
    create(:geographical_area, :with_reference_group_and_members, :with_description, geographical_area_id: '1000')
  end

  it { is_expected.to include_json(expected_pattern) }
end
