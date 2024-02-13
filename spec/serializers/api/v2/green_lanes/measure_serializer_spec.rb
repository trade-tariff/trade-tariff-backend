RSpec.describe Api::V2::GreenLanes::MeasureSerializer do
  subject { described_class.new(presented).serializable_hash.as_json }

  let(:presented) { Api::V2::GreenLanes::MeasurePresenter.new measure }
  let(:measure) { create :measure, :with_footnote_association }

  let :expected_pattern do
    {
      data: {
        id: measure.measure_sid.to_s,
        type: 'measure',
        attributes: {
          effective_start_date: measure.effective_start_date,
          effective_end_date: measure.effective_end_date,
        },
        relationships: {
          footnotes: {
            data: [
              { id: measure.footnotes.first.code.to_s, type: 'footnote' },
            ],
          },
        },
      },
    }
  end

  it { is_expected.to include_json(expected_pattern) }
end
