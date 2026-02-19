RSpec.describe LabelBatchPresenter do
  around { |example| TimeMachine.now { example.run } }

  let(:presenter) { described_class.new(batch) }
  let(:batch) { [commodity] }
  let(:commodity) { create(:commodity, :with_description, :with_ancestors) }

  describe '#goods_nomenclature_for' do
    it 'returns the goods nomenclature matching the item_id' do
      result = presenter.goods_nomenclature_for(commodity.goods_nomenclature_item_id)
      expect(result).to eq(commodity)
    end

    it 'returns nil when no match is found' do
      result = presenter.goods_nomenclature_for('9999999999')
      expect(result).to be_nil
    end
  end

  describe '#to_json' do
    subject(:json) { JSON.parse(presenter.to_json) }

    it 'returns an array of presented goods nomenclatures' do
      expect(json).to be_an(Array)
      expect(json.size).to eq(1)
    end

    it 'includes commodity_code' do
      expect(json.first['commodity_code']).to eq(commodity.goods_nomenclature_item_id)
    end

    it 'includes description' do
      expect(json.first['description']).to be_present
    end

    context 'when self-text is available in DB' do
      before do
        create(:goods_nomenclature_self_text,
               goods_nomenclature_sid: commodity.goods_nomenclature_sid,
               goods_nomenclature_item_id: commodity.goods_nomenclature_item_id,
               self_text: 'DB self-text description')
      end

      it 'uses the self-text as description' do
        expect(json.first['description']).to eq('DB self-text description')
      end
    end

    context 'when no self-text is available' do
      it 'uses normalised ancestor_chain_description' do
        expect(json.first['description']).to eq(
          DescriptionNormaliser.call(commodity.ancestor_chain_description),
        )
      end
    end
  end

  describe '#contextual_description_for' do
    context 'when self-text is available in DB' do
      before do
        create(:goods_nomenclature_self_text,
               goods_nomenclature_sid: commodity.goods_nomenclature_sid,
               goods_nomenclature_item_id: commodity.goods_nomenclature_item_id,
               self_text: 'DB self-text for commodity')
      end

      it 'returns the self-text' do
        expect(presenter.contextual_description_for(commodity)).to eq('DB self-text for commodity')
      end
    end

    context 'when no self-text record exists' do
      it 'falls back to normalised ancestor_chain_description' do
        expect(presenter.contextual_description_for(commodity)).to eq(
          DescriptionNormaliser.call(commodity.ancestor_chain_description),
        )
      end
    end

    context 'when ancestor_chain_description contains HTML' do
      before do
        allow(commodity).to receive(:ancestor_chain_description)
          .and_return('Live animals &ge; Horses<br>pure-bred &times; 2')
      end

      it 'normalises HTML in the fallback description' do
        result = presenter.contextual_description_for(commodity)

        expect(result).not_to include('<br>')
        expect(result).not_to include('&ge;')
        expect(result).not_to include('&times;')
        expect(result).to eq('Live animals >= Horses pure-bred x 2')
      end
    end

    context 'with multiple commodities in a batch' do
      let(:commodity2) { create(:commodity, :with_description) }
      let(:batch) { [commodity, commodity2] }

      before do
        create(:goods_nomenclature_self_text,
               goods_nomenclature_sid: commodity.goods_nomenclature_sid,
               goods_nomenclature_item_id: commodity.goods_nomenclature_item_id,
               self_text: 'First self-text')
        create(:goods_nomenclature_self_text,
               goods_nomenclature_sid: commodity2.goods_nomenclature_sid,
               goods_nomenclature_item_id: commodity2.goods_nomenclature_item_id,
               self_text: 'Second self-text')
      end

      it 'batch-loads all self-texts' do
        expect(presenter.contextual_description_for(commodity)).to eq('First self-text')
        expect(presenter.contextual_description_for(commodity2)).to eq('Second self-text')
      end
    end
  end
end
