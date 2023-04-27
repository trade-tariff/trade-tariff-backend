RSpec.describe QuotaOrderNumberOrigin do
  describe '#quota_order_number_origin_exclusion_ids' do
    context 'when there are quota exclusions' do
      subject(:quota_order_number_origin) { create(:quota_order_number_origin, :with_quota_order_number_origin_exclusion) }

      it 'returns the event ids' do
        expect(quota_order_number_origin.quota_order_number_origin_exclusion_ids.count).to be_positive
      end
    end

    context 'when there are no quota exclusions' do
      subject(:quota_order_number_origin) { create(:quota_order_number_origin) }

      it 'returns empty event ids' do
        expect(quota_order_number_origin.quota_order_number_origin_exclusion_ids).to eq([])
      end
    end
  end
end
