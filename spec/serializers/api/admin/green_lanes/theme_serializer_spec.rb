RSpec.describe Api::Admin::GreenLanes::ThemeSerializer do
  subject(:serialized) do
    described_class.new(theme).serializable_hash
  end

  let(:theme) { create :green_lanes_theme }

  let :expected do
    {
      data: {
        id: theme.id.to_s,
        type: :theme,
        attributes: {
          section: theme.section,
          subsection: theme.subsection,
          theme: theme.theme,
          description: theme.description,
          category: theme.category,
        },
      },
    }
  end

  describe '#serializable_hash' do
    it 'matches the expected hash' do
      expect(serialized).to eq(expected)
    end
  end
end
