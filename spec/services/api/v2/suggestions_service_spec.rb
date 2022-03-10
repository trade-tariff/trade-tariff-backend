RSpec.describe Api::V2::SuggestionsService do
  describe '#perform' do
    subject(:suggestions) do
      commodities && described_class.new.perform
    end

    let(:commodities) { create_list :commodity, 3 }
    let(:commodity_ids) { commodities.map(&:goods_nomenclature_item_id) }

    it { is_expected.to have_attributes length: commodities.length }
    it { is_expected.to all be_instance_of Api::V2::SuggestionPresenter }

    describe 'suggestions' do
      subject { suggestions.map(&:value) }

      it { is_expected.to match_array commodity_ids }

      context 'with hidden_goods_nomenclature_item_ids' do
        before do
          create :hidden_goods_nomenclature,
                 goods_nomenclature_item_id: commodities.first.goods_nomenclature_item_id
        end

        it { is_expected.to have_attributes length: 2 }
        it { is_expected.not_to include commodities.first.goods_nomenclature_item_id }
      end
    end
  end
end
