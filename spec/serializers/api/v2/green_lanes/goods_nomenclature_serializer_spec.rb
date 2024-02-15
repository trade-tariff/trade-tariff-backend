RSpec.describe Api::V2::GreenLanes::GoodsNomenclatureSerializer do
  subject(:serialized) do
    presented_assessments = [
      ::Api::V2::GreenLanes::CategoryAssessmentPresenter.new(category_assessment, [first_measure]),
    ]

    gn_presenter = \
      Api::V2::GreenLanes::GoodsNomenclaturePresenter.new(subheading, presented_assessments)

    described_class.new(
      gn_presenter,
      include: %w[applicable_category_assessments
                  applicable_category_assessments.geographical_area],
    ).serializable_hash
  end

  before do
    allow(GreenLanes::CategoryAssessment).to receive(:all).and_return([category_assessment])
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
              type: eq(:category_assessment),
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
          type: eq(:category_assessment),
          relationships: {
            measures: {
              data: [
                {
                  id: first_measure.measure_sid.to_s,
                  type: eq(:measure),
                },
              ],
            },
          },
        },
      ],
    }
  end

  let(:subheading) { create :subheading, :with_measures }
  let(:first_measure) { subheading.applicable_measures.first }

  let :category_assessment do
    build :category_assessment, measure: first_measure, geographical_area:
  end

  let :geographical_area do
    create(:geographical_area, :with_reference_group_and_members, :with_description, geographical_area_id: '1000')
  end

  it { is_expected.to include_json(expected_pattern) }
end
