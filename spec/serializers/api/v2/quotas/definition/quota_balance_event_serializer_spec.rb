require 'rails_helper'

RSpec.describe Api::V2::Quotas::Definition::QuotaBalanceEventSerializer do
  subject(:serializer) { described_class.new(serializable) }

  let(:serializable) { create(:quota_balance_event) }

  let(:expected_pattern) do
    {
      data: {
        id: be_a(String),
        type: 'quota_balance_event',
        attributes: {
          quota_definition_sid: be_a(Numeric),
          occurrence_timestamp: serializable.occurrence_timestamp.xmlschema(3),

          last_import_date_in_allocation: serializable.last_import_date_in_allocation.strftime('%Y-%m-%d'),
          old_balance: serializable.old_balance.to_s,
          new_balance: serializable.new_balance.to_s,
          imported_amount: serializable.imported_amount.to_s,
        },
      },
    }
  end

  describe '#serializable_hash' do
    it { expect(serializer.serializable_hash.as_json).to include_json(expected_pattern) }
  end
end
