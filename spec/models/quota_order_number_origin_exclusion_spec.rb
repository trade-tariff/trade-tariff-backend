RSpec.describe QuotaOrderNumberOriginExclusion do
  describe '#id' do
    subject(:exclusion) { build(:quota_order_number_origin_exclusion, quota_order_number_origin_sid: 111, excluded_geographical_area_sid: 222) }

    it { expect(exclusion.id).to eq('111-222') }
  end
end
