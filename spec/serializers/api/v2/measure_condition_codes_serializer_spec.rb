RSpec.describe Api::V2::MeasureConditionCodeSerializer do
  describe '#serializable_hash' do
    subject(:serializable_hash) { described_class.new(serializable).serializable_hash }

    let(:serializable) { create(:measure_condition_code, :with_description, condition_code: 'C') }

    let(:expected_pattern) do
      {
        data: {
          id: 'C',
          type: :measure_condition_code,
          attributes: {
            description: 'Presentation of a certificate/licence/document',
            validity_start_date: Time.zone.today.ago(3.years).as_json,
            validity_end_date: nil,
          },
        },
      }
    end

    it { is_expected.to eq(expected_pattern) }
  end
end
