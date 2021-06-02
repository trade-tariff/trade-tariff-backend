require 'rails_helper'

RSpec.describe Api::V2::Quotas::Definition::QuotaDefinitionSerializer do
  subject(:serializer) { described_class.new(serializable, options) }

  let(:serializable) { create(:quota_definition, :with_quota_balance_events) }
  let(:options) { {} }

  let(:expected_pattern) do
    {
      data: {
        id: be_a(String),
        type: 'definition',
        attributes: {
          quota_definition_sid: be_a(Numeric),
          quota_order_number_id: match(/09\d{4}/),
          initial_volume: nil,
          validity_start_date: nil,
          validity_end_date: nil,
          status: 'Open',
          description: nil,
          balance: serializable.balance.to_s,
          measurement_unit: nil,
          monetary_unit: be_a(String),
          measurement_unit_qualifier: be_a(String),
          last_allocation_date: serializable.last_balance_event.occurrence_timestamp.xmlschema(3),
          suspension_period_start_date: nil,
          suspension_period_end_date: nil,
          blocking_period_start_date: nil,
          blocking_period_end_date: nil,
        },
        relationships: {
          order_number: {},
          measures: {},
          quota_balance_events: {},
        },
      },
    }
  end

  describe '#serializable_hash' do
    it { expect(serializer.serializable_hash.as_json).to include_json(expected_pattern) }

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
