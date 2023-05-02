RSpec.describe QuotaOrderNumberOriginExclusion do
  describe '#id' do
    subject(:exclusion) { build(:quota_order_number_origin_exclusion, quota_order_number_origin_sid: 111, excluded_geographical_area_sid: 222, oid: 100) }

    it { expect(exclusion.id).to eq("#{exclusion.oid}-#{exclusion.quota_order_number_origin_sid}-#{exclusion.excluded_geographical_area_sid}") }
  end
end
