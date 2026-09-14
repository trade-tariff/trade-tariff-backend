RSpec.describe DifferencesReportCheckWorker, type: :worker do
  subject(:worker) { described_class.new }

  let(:completion_key) { DifferencesReportWorker::COMPLETION_KEY }

  describe '#perform' do
    before do
      allow(SlackNotifierService).to receive(:call).and_call_original
      allow(TradeTariffBackend).to receive_messages(environment: environment, uk?: uk)
    end

    context 'when the environment is production and the service is uk' do
      let(:environment) { ActiveSupport::StringInquirer.new('production') }
      let(:uk) { true }

      it 'is happy if the differences report completed this week' do
        DifferencesLog.create(date: Date.current.beginning_of_week, key: completion_key, value: 'completed')
        worker.perform
        expect(SlackNotifierService).not_to have_received(:call)
      end

      it 'is unhappy if the differences report last completed before this week' do
        DifferencesLog.create(date: 10.days.ago, key: completion_key, value: 'completed')
        worker.perform
        expect(SlackNotifierService).to have_received(:call)
      end

      it 'is unhappy if there is no differences report data at all' do
        worker.perform
        expect(SlackNotifierService).to have_received(:call)
      end

      # Previously a single worksheet log row counted as "the report has run".
      # Every worksheet loader writes its row before doing any work, so a run
      # that crashed part way through left rows behind and silenced this check.
      it 'is unhappy if only worksheet rows were written this week and the run never completed' do
        DifferencesLog.create(date: Date.current.beginning_of_week, key: 'Reporting::Differences::Loaders::MfnMissing', value: '[]')
        DifferencesLog.create(date: Date.current.beginning_of_week, key: 'Reporting::Differences::Loaders::Me32', value: '[]')
        worker.perform
        expect(SlackNotifierService).to have_received(:call)
      end
    end

    context 'when the environment is not production' do
      let(:environment) { ActiveSupport::StringInquirer.new('development') }
      let(:uk) { true }

      it 'is always happy' do
        DifferencesLog.create(date: 10.days.ago, key: completion_key, value: 'completed')
        worker.perform
        expect(SlackNotifierService).not_to have_received(:call)
      end
    end

    context 'when the service is not uk' do
      let(:environment) { ActiveSupport::StringInquirer.new('production') }
      let(:uk) { false }

      it 'is always happy' do
        DifferencesLog.create(date: 10.days.ago, key: completion_key, value: 'completed')
        worker.perform
        expect(SlackNotifierService).not_to have_received(:call)
      end
    end
  end
end
