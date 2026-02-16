RSpec.describe SearchSuggestionPopulatorService do
  subject(:call) { described_class.new.call }

  before do
    create(:search_reference, :with_heading, title: 'gold ore')
    create(:chapter, goods_nomenclature_item_id: '0100000000')
    create(:heading, goods_nomenclature_item_id: '0101000000')
    create(:commodity, goods_nomenclature_item_id: '0101090000')
    create(:commodity, :with_children, goods_nomenclature_item_id: '0101090001')

    allow(SuggestionsService).to receive(:new).and_call_original
  end

  it { expect { call }.to change(SearchSuggestion, :count).by(9) }

  it 'creates search suggestions with the proper value' do
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

    expect(SuggestionsService).to have_received(:new)
  end

  context 'when the search suggestion already exists' do
    before do
      create(:search_suggestion, :search_reference, value: 'gold ore')
    end

    it { expect { call }.not_to raise_error }
  end

  context 'when some search suggestions belong to expired goods nomenclature' do
    before do
      current_goods_nomenclature = create(
        :goods_nomenclature,
        :with_indent,
        goods_nomenclature_item_id: '0101090002',
      )

      expired_goods_nomenclature = create(
        :goods_nomenclature,
        :with_indent,
        goods_nomenclature_item_id: '0101090003',
        validity_start_date: 2.years.ago,
        validity_end_date: 1.year.ago,
      )

      create(
        :search_suggestion,
        :goods_nomenclature,
        id: current_goods_nomenclature.goods_nomenclature_sid,
        value: '0101090002',
      )
      create(
        :search_suggestion,
        :goods_nomenclature,
        id: expired_goods_nomenclature.goods_nomenclature_sid,
        value: '0101090003',
      )
    end

    let(:change_current) { change { SearchSuggestion.find(value: '0101090002')&.value } }
    let(:change_expired) { change { SearchSuggestion.find(value: '0101090003') } }

    it 'does not remove the current search suggestions' do
      expect { call }.not_to change_current
    end

    it 'removes the expired search suggestions' do
      expect { call }.to change_expired.to(nil)
    end
  end

  context 'when some search suggestions belong to removed search references' do
    let!(:search_suggestion) do
      create(
        :search_suggestion,
        :search_reference,
        id: 'orphaned',
        value: 'something else',
      )
    end

    it 'removes the no longer existing search reference search suggestion' do
      expect { call }.to change { SearchSuggestion.where(id: search_suggestion.id).first }.to(nil)
    end
  end
end
