RSpec.describe Api::V2::GreenLanes::ThemeSerializer do
  subject { described_class.new(theme).serializable_hash.as_json }

  let(:theme) { create :green_lanes_theme }

  let :expected_pattern do
    {
      data: {
        id: theme.code,
        type: 'theme',
        attributes: {
          id: theme.code,
          theme: theme.description,
          category: theme.category,
        },
      },
    }
  end

  it { is_expected.to include_json(expected_pattern) }
end
