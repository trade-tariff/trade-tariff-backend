RSpec.describe EnquiryForm::Submission do
  subject(:submission) { described_class.from(form_data) }

  let(:form_data) do
    {
      name: 'John Doe',
      email: 'john@example.com',
      test_condition: test_condition,
      reference_number: 'ABC12345',
    }
  end
  let(:test_condition) { 'none' }

  describe '.from' do
    it 'normalises string keys' do
      submission = described_class.from(form_data.stringify_keys)

      expect(submission.to_h).to eq(form_data)
    end
  end

  describe '#audiences' do
    it 'only includes HMRC for an unflagged submission' do
      expect(submission.audiences).to eq([described_class::HMRC_AUDIENCE])
    end

    context 'with a feature flag' do
      let(:test_condition) { 'Interactive search' }

      it 'includes independent HMRC and Trade Tariff deliveries' do
        expect(submission.audiences).to eq(
          [described_class::HMRC_AUDIENCE, described_class::TRADE_TARIFF_AUDIENCE],
        )
      end
    end
  end

  describe '#delivery_for' do
    it 'retains contact details for HMRC' do
      delivery = submission.delivery_for(described_class::HMRC_AUDIENCE)

      expect(delivery).to have_attributes(
        audience: described_class::HMRC_AUDIENCE,
        recipient: 'support@example.com',
        form_data: hash_including(name: 'John Doe', email: 'john@example.com'),
      )
    end

    context 'with a feature flag' do
      let(:test_condition) { 'Interactive search' }

      it 'uses the configured support recipient and redacts contact details for Trade Tariff' do
        allow(TradeTariffBackend).to receive(:support_email)
          .and_return('Online Trade Tariff Support <team@example.com>')

        delivery = submission.delivery_for(described_class::TRADE_TARIFF_AUDIENCE)

        expect(delivery).to have_attributes(
          audience: described_class::TRADE_TARIFF_AUDIENCE,
          recipient: 'team@example.com',
        )
        expect(delivery.form_data).not_to include(:name, :email)
      end
    end
  end
end
