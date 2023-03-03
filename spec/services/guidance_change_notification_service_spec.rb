RSpec.describe GuidanceChangeNotificationService do
  subject(:guidance_change_notification_service) do
    described_class.new(new_guidance, existing_guidance)
  end

  let(:new_guidance) do
    {
      'foo' => 'bar',
      'baz' => 'qux', # Changed
      'quux' => 'quuz', # Added
    }
  end

  let(:existing_guidance) do
    {
      'foo' => 'bar',
      'baz' => 'quux',
      'corge' => 'grault', # Removed
    }
  end

  describe '#call' do
    subject(:call) { guidance_change_notification_service.call }

    it 'calls SlackNotifierService with the correct message' do
      expect(SlackNotifierService).to receive(:call).with(
        'Chief CDS Guidance has been hot refreshed. </br>Added: quux </br>Removed: corge </br>Content changed: baz',
      )

      call
    end
  end
end
