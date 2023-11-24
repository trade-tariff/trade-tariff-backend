RSpec.describe Api::V2::GreenLanes::SubheadingSerializer do
  subject(:serialized) do
    described_class.new(subheading_presenter, include: %w[applicable_measures]).serializable_hash
  end

  let(:subheading_presenter) { Api::V2::GreenLanes::SubheadingPresenter.new(subheading) }

  let(:subheading) { create :subheading, :with_measures }

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
        },
      },
      included: [{
        id: subheading.applicable_measures.first.id.to_s,
        type: eq(:measure),
      }],
    }
  end

  it { is_expected.to include_json(expected_pattern) }
end
