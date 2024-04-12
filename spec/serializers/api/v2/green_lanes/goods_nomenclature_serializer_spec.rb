RSpec.describe Api::V2::GreenLanes::GoodsNomenclatureSerializer do
  subject(:serialized) do
    gn_presenter = \
      Api::V2::GreenLanes::GoodsNomenclaturePresenter.new(subheading, presented_assessments)

    described_class.new(
      gn_presenter,
      include: %w[applicable_category_assessments
                  applicable_category_assessments.geographical_area],
    ).serializable_hash
  end

  let(:subheading) { create :subheading, :with_measures }
  let(:assessment) { create :category_assessment, measure: subheading.measures.first }

  let :permutations do
    GreenLanes::PermutationCalculatorService.new(subheading.applicable_measures).call
  end

  let :presented_assessments do
    [Api::V2::GreenLanes::CategoryAssessmentPresenter.new(assessment, *permutations.first)]
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
              "id": presented_assessments[0].id,
              type: eq(:category_assessment),
            }],
          },
        },
      },
      included: [
        {
          id: subheading.measures.first.geographical_area_id,
          type: eq(:geographical_area),
        },
        {
          id: presented_assessments[0].id,
          type: eq(:category_assessment),
          relationships: {
            measures: {
              data: [
                {
                  id: subheading.measures.first.measure_sid.to_s,
                  type: eq(:measure),
                },
              ],
            },
          },
        },
      ],
    }
  end

  it { is_expected.to include_json(expected_pattern) }
end
