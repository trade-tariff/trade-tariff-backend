RSpec.describe Api::V2::GreenLanes::ExemptionPresenter do
  subject { described_class.new(exemption) }

  let(:exemption) { create :green_lanes_exemption }

  it { is_expected.to have_attributes id: exemption.code }
  it { is_expected.to have_attributes code: exemption.code }
  it { is_expected.to have_attributes description: exemption.description }
  it { is_expected.to have_attributes formatted_description: exemption.description }
end
