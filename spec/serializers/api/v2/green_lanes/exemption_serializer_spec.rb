RSpec.describe Api::V2::GreenLanes::ExemptionSerializer do
  subject { described_class.new(presented).serializable_hash.as_json }

  let(:exemption) { create :green_lanes_exemption }
  let(:presented) { Api::V2::GreenLanes::ExemptionPresenter.new exemption }

  let(:expected_pattern) do
    {
      data: {
        id: exemption.code,
        type: 'exemption',
        attributes: {
          code: exemption.code,
          description: exemption.description,
          formatted_description: exemption.description,
        },
      },
    }
  end

  it { is_expected.to include_json(expected_pattern) }
end
