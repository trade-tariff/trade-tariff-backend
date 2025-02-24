RSpec.describe Api::V2::Quotas::OrderNumber::QuotaDefinitionSerializer do
  describe '#serializable_hash' do
    subject(:serializable_hash) { described_class.new(serializable, options).serializable_hash.as_json }

    let(:serializable) { create(:quota_definition, :with_quota_balance_events) }
    let(:expected_pattern) do
      {
        data: {
          id: be_a(String),
          type: 'definition',
          attributes: {
            initial_volume: nil,
            validity_start_date: 4.years.ago.beginning_of_day.as_json,
            validity_end_date: nil,
            status: 'Open',
            description: nil,
            balance: serializable.balance.to_s,
            measurement_unit: nil,
            monetary_unit: be_a(String),
            measurement_unit_qualifier: be_a(String),
            last_allocation_date: serializable.last_balance_event.last_import_date_in_allocation.beginning_of_day.iso8601,
            suspension_period_start_date: nil,
            suspension_period_end_date: nil,
            blocking_period_start_date: nil,
            blocking_period_end_date: nil,
          },
          relationships: {
            incoming_quota_closed_and_transferred_event: {},
          },
        },
      }
    end
    let(:options) { {} }

    before do
      allow(serializable).to receive(:shows_balance_transfers?).and_return(true)
    end

    it { is_expected.to include_json(expected_pattern) }

    it 'asks the quota definition is balance transfers should be shown' do
      serializable_hash

      expect(serializable).to have_received(:shows_balance_transfers?)
    end
  end
end
