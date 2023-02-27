RSpec.describe PopulateSearchSuggestionsWorker, type: :worker do
  subject(:worker) { described_class.new }

  before do
    create(:search_reference, :with_heading, title: 'gold ore')
  end

  it 'creates search suggestions with the proper value' do
    worker.perform

    search_suggestions = SearchSuggestion.all.pluck(:value)

    expect(search_suggestions).to include(
      'gold ore',
      '0101',
    )
  end
end
