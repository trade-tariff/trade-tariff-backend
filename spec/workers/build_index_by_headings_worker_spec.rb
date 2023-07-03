RSpec.describe BuildIndexByHeadingsWorker, type: :worker do
  describe '#perform' do
    let!(:heading) { create(:heading, :non_grouping) }

    let(:index_name) { 'Search::BulkSearchIndex' }

    before do
      create(:heading, :grouping)   # not queued
      create(:heading, :classified) # not queued
      create(:heading, :hidden)     # not queued
      create(:commodity)            # not queued

      allow(BuildIndexByHeadingWorker).to receive(:perform_async)
    end

    it 'enqueues a BuildIndexByHeadingWorker for each heading' do
      described_class.new.perform(index_name)

      expect(BuildIndexByHeadingWorker).to have_received(:perform_async).with(index_name, heading.heading_short_code)
    end
  end
end
