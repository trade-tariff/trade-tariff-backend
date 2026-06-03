RSpec.describe EnquiryForm::SubmissionFormatter do
  describe '#notify_category' do
    it 'returns the Notify subject category tag' do
      {
        'classification' => 'classification',
        'api_dev_portal_support' => 'api_dev_portal_support',
        'customs_valuation' => 'customs_valuation',
        'import_duties' => 'import_duties',
        'import_duties_and_quota' => 'import_duties',
        'import_duties_and_quotas' => 'import_duties',
        'valuation' => 'customs_valuation',
        'quotas' => 'import_duties',
        'origin' => 'origin',
        'stop_press_subscription' => 'stop_press_subscriptions',
        'stop_press_and_commodity_code_watch_lists' => 'stop_press_subscriptions',
        'tariff_watch_lists' => 'stop_press_subscriptions',
        'developer_portal' => 'api_dev_portal_support',
        'other' => 'other',
        'Classification' => 'other',
        'unexpected' => 'other',
      }.each do |enquiry_category, notify_category|
        formatter = described_class.new(enquiry_category: enquiry_category)

        expect(formatter.notify_category).to eq(notify_category)
      end
    end
  end

  describe '#enquiry_description' do
    it 'returns an empty string when no enquiry details are present' do
      formatter = described_class.new(enquiry_category: 'classification')

      expect(formatter.enquiry_description).to eq('')
    end
  end
end
