RSpec.describe Api::Admin::GreenLanes::CategoryAssessmentSerializer do
  subject { described_class.new(category).serializable_hash.as_json }

  let(:category) { create :category_assessment }

  let :expected do
    {
      data: {
        id: category.id.to_s,
        type: 'category_assessment',
        attributes: {
          measure_type_id: category.measure_type_id,
          regulation_id: category.regulation_id,
          regulation_role: category.regulation_role,
        },
        relationships: {
          theme: {
            data: { id: category.theme_id.to_s, type: 'theme' },
          },
        },
      },
    }
  end

  it { is_expected.to include_json(expected) }
end
