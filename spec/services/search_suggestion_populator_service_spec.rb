RSpec.describe SearchSuggestionPopulatorService do
  subject(:call) { described_class.new.call }

  before do
    create(:search_reference, :with_heading, title: 'gold ore')
    create(:chapter, goods_nomenclature_item_id: '0100000000')
    create(:heading, goods_nomenclature_item_id: '0101000000')
    create(:commodity, goods_nomenclature_item_id: '0101090000')

    allow(Api::V2::SuggestionsService).to receive(:new).and_call_original
  end

  it { expect { call }.to change(SearchSuggestion, :count).by(5) }

  it 'creates search suggestions with the proper id and value' do
    call

    search_suggestions = SearchSuggestion.all.pluck(:value)

    expect(search_suggestions).to include(
      'gold ore',
      '01',
      '0101',
      '0101090000',
    )
  end

  it 'calls the SuggestionsService' do
    call

    expect(Api::V2::SuggestionsService).to have_received(:new)
  end

  context 'when the search suggestion already exists' do
    before do
      create(:search_suggestion, value: 'gold ore')
    end

    it { expect { call }.not_to raise_error }
  end
end
