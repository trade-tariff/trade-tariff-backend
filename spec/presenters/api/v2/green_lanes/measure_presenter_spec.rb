RSpec.describe Api::V2::GreenLanes::MeasurePresenter do
  subject { described_class.new(measure) }

  let(:measure) { create :measure, :with_footnote_association }
  let(:footnotes) { measure.footnotes }

  it { is_expected.to have_attributes id: measure.measure_sid }
  it { is_expected.to have_attributes footnotes: }
  it { is_expected.to have_attributes footnote_ids: footnotes.map(&:code) }
end
