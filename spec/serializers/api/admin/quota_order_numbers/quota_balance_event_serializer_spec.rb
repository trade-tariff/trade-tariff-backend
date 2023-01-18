RSpec.describe Api::Admin::QuotaOrderNumbers::QuotaBalanceEventSerializer do
  describe '#serializable_hash' do
    subject(:serialized) { described_class.new(serializable).serializable_hash }

    let(:serializable) { build(:quota_balance_event) }

    let(:expected) do
      {
        data: {
          id: "#{serializable.quota_definition_sid}-#{serializable.occurrence_timestamp.iso8601}",
          type: :quota_balance_event,
          attributes: {
            occurrence_timestamp: serializable.occurrence_timestamp,
            new_balance: serializable.new_balance,
            imported_amount: serializable.imported_amount,
            last_import_date_in_allocation: serializable.last_import_date_in_allocation,
            old_balance: serializable.old_balance,
          },
        },
      }
    end

    it { is_expected.to eq(expected) }
  end
end
