RSpec.describe SearchReferences::PublicSearchRemoval do
  subject(:call) { described_class.call(search_reference, previous_usage:) }

  let(:search_reference) { create(:search_reference, usage:) }
  let(:suggestions) { SearchSuggestion.search_reference_type.where(id: search_reference.id.to_s) }

  before do
    create(:search_suggestion, :search_reference, id: search_reference.id.to_s)
    allow(TradeTariffBackend.search_client).to receive(:delete)
  end

  shared_examples 'removes it from public search' do
    it 'deletes its search suggestion' do
      expect { call }.to change(suggestions, :count).from(1).to(0)
    end

    it 'deletes it from the search index' do
      call

      expect(TradeTariffBackend.search_client).to have_received(:delete).with(Search::SearchReferenceIndex, search_reference)
    end
  end

  shared_examples 'leaves public search alone' do
    it 'keeps its search suggestion' do
      expect { call }.not_to change(suggestions, :count)
    end

    it 'does not touch the search index' do
      call

      expect(TradeTariffBackend.search_client).not_to have_received(:delete)
    end
  end

  context 'when it changes from search to fpo' do
    let(:usage) { 'fpo' }
    let(:previous_usage) { 'search' }

    it_behaves_like 'removes it from public search'
  end

  context 'when it is re-created as fpo' do
    let(:usage) { 'fpo' }
    let(:previous_usage) { nil }

    it_behaves_like 'removes it from public search'
  end

  context 'when it was already fpo' do
    let(:usage) { 'fpo' }
    let(:previous_usage) { 'fpo' }

    it_behaves_like 'leaves public search alone'
  end

  context 'when it is a search reference' do
    let(:usage) { 'search' }
    let(:previous_usage) { 'fpo' }

    it_behaves_like 'leaves public search alone'
  end

  context 'when the search index has no document for it' do
    let(:usage) { 'fpo' }
    let(:previous_usage) { 'search' }

    before do
      allow(TradeTariffBackend.search_client).to receive(:delete)
        .and_raise(OpenSearch::Transport::Transport::Errors::NotFound)
    end

    it 'still deletes its search suggestion' do
      expect { call }.to change(suggestions, :count).from(1).to(0)
    end
  end
end
