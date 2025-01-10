RSpec.describe TreeIntegrityCheckWorker, type: :worker do
  let(:date) { Time.zone.today }

  describe '#perform' do
    before do
      allow(::Sentry).to receive(:capture_message)
      commodity

      described_class.new.perform
    end

    context 'with valid tree' do
      let(:commodity) { create :commodity, :with_chapter_and_heading }

      it 'takes no action' do
        expect(Sentry).not_to have_received(:capture_message)
      end
    end

    context 'with invalid tree' do
      let(:commodity) { create :commodity, :with_chapter_and_heading, indents: 2 }

      it 'alerts with the failing ids' do
        expect(Sentry).to have_received(:capture_message).with(%r{Tree integrity check failed for \d{4}-\d\d-\d\d}).exactly(4).times
      end
    end
  end
end
