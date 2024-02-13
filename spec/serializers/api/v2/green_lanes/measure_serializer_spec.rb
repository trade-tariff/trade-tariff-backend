RSpec.describe Api::V2::GreenLanes::MeasureSerializer do
  subject { described_class.new(measure).serializable_hash.as_json }

  let(:measure) { create :measure }

  let :expected_pattern do
    {
      data: {
        id: measure.measure_sid.to_s,
        type: 'measure',
        attributes: {
          effective_start_date: measure.effective_start_date,
          effective_end_date: measure.effective_end_date,
        },
      },
    }
  end

  it { is_expected.to include_json(expected_pattern) }
end
