RSpec.describe DifferencesReportCheckWorker, type: :worker do
  subject(:worker) { described_class.new }

  describe '#perform' do
    before do
      allow(SlackNotifierService).to receive(:call).and_call_original
    end

    it 'is happy if the differences report has run this week' do
      DifferencesLog.create(date: Time.zone.yesterday, key: 'foo', value: 'foo')
      worker.perform
      expect(SlackNotifierService).not_to have_received(:call)
    end

    it 'is unhappy if the differences report has not run this week' do
      allow(ENV).to receive(:fetch).and_return('production')
      DifferencesLog.create(date: 10.days.ago, key: 'foo', value: 'foo')
      worker.perform
      expect(SlackNotifierService).to have_received(:call)
    end
  end
end
