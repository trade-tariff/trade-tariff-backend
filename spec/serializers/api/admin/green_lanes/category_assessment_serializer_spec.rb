RSpec.describe Api::Admin::GreenLanes::CategoryAssessmentSerializer do
  subject(:serialized) do
    described_class.new(category).serializable_hash
  end

  let(:category) { create :category_assessment }

  let :expected do
    {
      data: {
        id: category.id.to_s,
        type: :category_assessment,
        attributes: {
          measure_type_id: category.measure_type_id,
          regulation_id: category.regulation_id,
          regulation_role: category.regulation_role,
          theme_id: category.theme_id,
          created_at: category.created_at,
          updated_at: category.updated_at,
        },
      }
    }
  end

  describe '#serializable_hash' do
    it 'matches the expected hash' do
      expect(serialized).to eq(expected)
    end
  end
end
