RSpec.describe DifferencesReportCheckWorker, type: :worker do
  subject(:worker) { described_class.new }

  describe '#perform' do
    before do
      allow(SlackNotifierService).to receive(:call).and_call_original
      allow(TradeTariffBackend).to receive_messages(environment: environment, uk?: uk)
    end

    context 'when the environment is production and the service is uk' do
      let(:environment) { ActiveSupport::StringInquirer.new('production') }
      let(:uk) { true }

      it 'is happy if the differences report has run this week' do
        DifferencesLog.create(date: Time.zone.yesterday, key: 'foo', value: 'foo')
        worker.perform
        expect(SlackNotifierService).not_to have_received(:call)
      end

      it 'is unhappy if the differences report has not run this week' do
        DifferencesLog.create(date: 10.days.ago, key: 'foo', value: 'foo')
        worker.perform
        expect(SlackNotifierService).to have_received(:call)
      end

      it 'is unhappy if there is no differences report data' do
        worker.perform
        expect(SlackNotifierService).to have_received(:call)
      end
    end

    context 'when the environment is not production' do
      let(:environment) { ActiveSupport::StringInquirer.new('development') }
      let(:uk) { true }

      it 'is always happy' do
        DifferencesLog.create(date: 10.days.ago, key: 'foo', value: 'foo')
        worker.perform
        expect(SlackNotifierService).not_to have_received(:call)
      end
    end

    context 'when the service is not uk' do
      let(:environment) { ActiveSupport::StringInquirer.new('production') }
      let(:uk) { false }

      it 'is always happy' do
        DifferencesLog.create(date: 10.days.ago, key: 'foo', value: 'foo')
        worker.perform
        expect(SlackNotifierService).not_to have_received(:call)
      end
    end
  end
end
