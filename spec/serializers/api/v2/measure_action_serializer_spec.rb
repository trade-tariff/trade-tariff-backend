RSpec.describe Api::V2::MeasureActionSerializer do
  describe '#serializable_hash' do
    subject(:serializable_hash) { described_class.new(serializable).serializable_hash }

    let(:serializable) { create(:measure_action, :with_description, action_code: '01') }

    let(:expected_pattern) do
      {
        data: {
          id: '01',
          type: :measure_action,
          attributes: {
            description: 'Import/export not allowed after control',
            validity_start_date: Time.zone.today - 3.years,
            validity_end_date: nil,
          },
        },
      }
    end

    it { is_expected.to eq(expected_pattern) }
  end
end
