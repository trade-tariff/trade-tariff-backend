RSpec.describe LabelBatchPresenter do
  around { |example| TimeMachine.now { example.run } }

  let(:presenter) { described_class.new(batch) }
  let(:batch) { [commodity] }
  let(:commodity) { create(:commodity, :with_description, :with_ancestors) }

  before do
    SelfTextLookupService.instance_variable_set(:@self_texts, nil)
    SelfTextLookupService.instance_variable_set(:@csv_path, nil)
  end

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

    context 'when self-text is available' do
      before do
        allow(SelfTextLookupService).to receive(:lookup)
          .with(commodity.goods_nomenclature_item_id)
          .and_return('Self-text description from CN2026')
      end

      it 'uses the self-text as description' do
        expect(json.first['description']).to eq('Self-text description from CN2026')
      end
    end

    context 'when no self-text is available' do
      before do
        allow(SelfTextLookupService).to receive(:lookup).and_return(nil)
      end

      it 'uses ancestor_chain_description' do
        expect(json.first['description']).to eq(commodity.ancestor_chain_description)
      end
    end
  end

  describe '#contextual_description_for' do
    context 'when self-text is available' do
      before do
        allow(SelfTextLookupService).to receive(:lookup)
          .with(commodity.goods_nomenclature_item_id)
          .and_return('CN2026 self-text')
      end

      it 'returns the self-text' do
        expect(presenter.contextual_description_for(commodity)).to eq('CN2026 self-text')
      end
    end

    context 'when self-text is blank' do
      before do
        allow(SelfTextLookupService).to receive(:lookup).and_return('')
      end

      it 'falls back to ancestor_chain_description' do
        expect(presenter.contextual_description_for(commodity)).to eq(commodity.ancestor_chain_description)
      end
    end

    context 'when self-text is nil' do
      before do
        allow(SelfTextLookupService).to receive(:lookup).and_return(nil)
      end

      it 'falls back to ancestor_chain_description' do
        expect(presenter.contextual_description_for(commodity)).to eq(commodity.ancestor_chain_description)
      end
    end
  end
end
