RSpec.describe Api::V2::Quotas::QuotaClosedAndTransferredEventSerializer do
  subject(:serializer) { described_class.new(serializable) }

  let(:serializable) { create(:quota_closed_and_transferred_event, :with_quota_definition, :with_target_quota_definition) }

  let(:expected_pattern) do
    {
      data: {
        id: be_a(String),
        type: 'quota_closed_and_transferred_event',
        attributes: {
          transferred_amount: be_a(Float),
          closing_date: be_a(String),
          quota_definition_validity_start_date: be_a(String),
          quota_definition_validity_end_date: nil,
          quota_definition_measurement_unit: nil,
          target_quota_definition_validity_start_date: be_a(String),
          target_quota_definition_validity_end_date: nil,
          target_quota_definition_measurement_unit: nil,
        },
      },
    }
  end

  describe '#serializable_hash' do
    it { expect(serializer.serializable_hash.as_json).to include_json(expected_pattern) }
  end
end
