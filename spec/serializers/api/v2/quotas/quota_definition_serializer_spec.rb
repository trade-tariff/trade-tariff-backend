RSpec.describe Api::V2::Quotas::QuotaDefinitionSerializer do
  subject(:serializer) { described_class.new(serializable, options) }

  let(:serializable) { create(:quota_definition, :with_quota_balance_events) }
  let(:expected_pattern) do
    {
      data: {
        id: be_a(String),
        type: 'definition',
        attributes: {
          quota_definition_sid: be_a(Numeric),
          quota_order_number_id: match(/09\d{4}/),
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
          order_number: {},
          measures: {},
          quota_balance_events: {},
          incoming_quota_closed_and_transferred_event: {},
          quota_order_number_origins: {},
        },
      },
    }
  end
  let(:options) { {} }

  before do
    allow(serializable).to receive(:shows_balance_transfers?).and_return(true)
  end

  describe '#serializable_hash' do
    it { expect(serializer.serializable_hash.as_json).to include_json(expected_pattern) }

    it 'asks the quota definition is balance transfers should be shown' do
      serializer.serializable_hash

      expect(serializable).to have_received(:shows_balance_transfers?)
    end

    context 'when passing include options' do
      before do
        expected_pattern[:data].merge(included_pattern)
        expected_pattern[:data][:relationships][:quota_balance_events] = {
          data: [
            {
              id: be_a(String),
              type: 'quota_balance_event',
            },
          ],
        }
      end

      let(:options) { { include: [:quota_balance_events] } }

      let(:included_pattern) { { included: [{ id: be_a(String), type: 'quota_balance_event' }] } }

      it { expect(serializer.serializable_hash.as_json).to include_json(expected_pattern) }
    end
  end
end
