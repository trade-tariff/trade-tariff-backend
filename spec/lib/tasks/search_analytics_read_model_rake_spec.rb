# frozen_string_literal: true

RSpec.describe 'search analytics read model rake tasks' do
  describe 'search_analytics:rebuild_read_model' do
    let(:task) { Rake::Task['search_analytics:rebuild_read_model'] }
    let(:model) do
      instance_double(SearchAnalyticsReadModel, id: 12, service: 'uk', region: 'eu-west-2', version: SearchAnalyticsReadModel::VERSION)
    end

    before do
      task.reenable
      allow(ENV).to receive(:fetch).and_call_original
      allow(ENV).to receive(:[]).and_call_original
      allow(SearchAnalytics::ReadModelRefresh).to receive(:call).and_return(model)
    end

    it 'rebuilds with the default region and no date bounds' do
      allow(ENV).to receive(:[]).with('FROM').and_return(nil)
      allow(ENV).to receive(:[]).with('TO').and_return(nil)

      expect { task.invoke }.to output(/Read model 12 for uk eu-west-2 version 1/).to_stdout
      expect(SearchAnalytics::ReadModelRefresh).to have_received(:call).with(hash_including(from: nil, to: nil))
    end

    it 'reports an occupied rebuild lock without claiming success' do
      allow(SearchAnalytics::ReadModelRefresh).to receive(:call).and_raise(Sequel::AdvisoryLockError)
      expect { task.invoke }.to output(/Another read-model refresh is running/).to_stderr.and raise_error(SystemExit) { |error| expect(error.status).to eq(1) }
    end

    it 'passes optional FROM and TO bounds' do
      allow(ENV).to receive(:[]).with('FROM').and_return('2026-09-01')
      allow(ENV).to receive(:[]).with('TO').and_return('2026-09-14')

      expect { task.invoke }.to output(/Read model 12/).to_stdout
      expect(SearchAnalytics::ReadModelRefresh).to have_received(:call).with(hash_including(from: '2026-09-01', to: '2026-09-14'))
    end
  end
end
