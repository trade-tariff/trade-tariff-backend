# frozen_string_literal: true

RSpec.describe 'search analytics materialized view rake tasks' do
  describe 'search_analytics:refresh_views' do
    let(:task) { Rake::Task['search_analytics:refresh_views'] }

    before do
      task.reenable
      allow(ENV).to receive(:[]).and_call_original
      allow(SearchAnalytics::MaterializedViews).to receive(:refresh!).and_return(true)
    end

    it 'refreshes views without waiting for the lock' do
      allow(ENV).to receive(:[]).with('WAIT').and_return(nil)
      allow(ENV).to receive(:[]).with('FORCE').and_return(nil)

      expect { task.invoke }.to output(/Refreshed search analytics materialized views/).to_stdout
      expect(SearchAnalytics::MaterializedViews).to have_received(:refresh!).with(wait: false, force: false)
    end

    it 'waits for the lock when WAIT is true' do
      allow(ENV).to receive(:[]).with('WAIT').and_return('true')
      allow(ENV).to receive(:[]).with('FORCE').and_return(nil)

      expect { task.invoke }.to output(/Refreshed search analytics materialized views/).to_stdout
      expect(SearchAnalytics::MaterializedViews).to have_received(:refresh!).with(hash_including(wait: true, force: false))
    end

    it 'forces a rebuild when FORCE is true' do
      allow(ENV).to receive(:[]).with('WAIT').and_return(nil)
      allow(ENV).to receive(:[]).with('FORCE').and_return('true')

      expect { task.invoke }.to output(/Refreshed search analytics materialized views/).to_stdout
      expect(SearchAnalytics::MaterializedViews).to have_received(:refresh!).with(hash_including(force: true))
    end

    it 'reports when source revisions already match' do
      allow(SearchAnalytics::MaterializedViews).to receive(:refresh!).and_return(false)

      expect { task.invoke }.to output(/already match source revisions/).to_stdout
    end

    it 'reports an occupied refresh lock without claiming success' do
      allow(SearchAnalytics::MaterializedViews).to receive(:refresh!).and_raise(Sequel::AdvisoryLockError)
      expect { task.invoke }.to output(/Another search analytics view refresh is running/).to_stderr.and raise_error(SystemExit) { |error| expect(error.status).to eq(1) }
    end
  end
end
