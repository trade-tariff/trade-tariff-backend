RSpec.describe DeltaReportService::CommodityChanges do
  let(:date) { Date.parse('2024-08-11') }

  let(:goods_nomenclature) { build(:goods_nomenclature, goods_nomenclature_item_id: '0101000000') }
  let(:instance) { described_class.new(goods_nomenclature, date) }

  before do
    allow(instance).to receive(:get_changes)
  end

  describe '.collect' do
    let(:goods_nomenclature1) { build(:goods_nomenclature, oid: 1, operation_date: date) }
    let(:goods_nomenclature2) { build(:goods_nomenclature, oid: 2, operation_date: date) }
    let(:goods_nomenclatures) { [goods_nomenclature1, goods_nomenclature2] }

    before do
      allow(GoodsNomenclature).to receive(:where).and_return(goods_nomenclatures)
    end

    it 'finds goods nomenclatures for the given date and returns analyzed changes' do
      instance1 = described_class.new(goods_nomenclature1, date)
      instance2 = described_class.new(goods_nomenclature2, date)

      allow(described_class).to receive(:new).and_return(instance1, instance2)
      allow(instance1).to receive(:analyze).and_return({ type: 'GoodsNomenclature' })
      allow(instance2).to receive(:analyze).and_return({ type: 'GoodsNomenclature' })

      result = described_class.collect(date)

      expect(GoodsNomenclature).to have_received(:where).with(operation_date: date)
      expect(result).to eq([{ type: 'GoodsNomenclature' }, { type: 'GoodsNomenclature' }])
    end
  end

  describe '#object_name' do
    it 'returns the correct object name' do
      expect(instance.object_name).to eq('Commodity')
    end
  end

  describe '#analyze' do
    before do
      allow(instance).to receive_messages(
        no_changes?: false,
        date_of_effect: date,
        description: 'Commodity added',
        change: nil,
      )
    end

    context 'when there are no changes' do
      before { allow(instance).to receive(:no_changes?).and_return(true) }

      it 'returns nil' do
        expect(instance.analyze).to be_nil
      end
    end

    context 'when changes should be included' do
      it 'returns the correct analysis hash' do
        result = instance.analyze

        expect(result).to eq({
          type: 'GoodsNomenclature',
          goods_nomenclature_sid: goods_nomenclature.goods_nomenclature_sid,
          date_of_effect: date,
          description: 'Commodity added',
          change: '0101000000',
        })
      end
    end

    context 'when change is not nil' do
      before { allow(instance).to receive(:change).and_return('updated description') }

      it 'uses the change value instead of code' do
        result = instance.analyze
        expect(result[:change]).to eq('updated description')
      end
    end

    context 'when record is a create operation for a non-declarable commodity' do
      before do
        allow(goods_nomenclature).to receive_messages(operation: :create, declarable?: false)
      end

      it 'returns nil for non-declarable commodities on create' do
        result = instance.analyze
        expect(result).to be_nil
      end
    end

    context 'when record is a create operation for a declarable commodity' do
      before do
        allow(goods_nomenclature).to receive_messages(operation: :create, declarable?: true)
      end

      it 'returns analysis for declarable commodities on create' do
        result = instance.analyze

        expect(result).to eq({
          type: 'GoodsNomenclature',
          goods_nomenclature_sid: goods_nomenclature.goods_nomenclature_sid,
          date_of_effect: date,
          description: 'Commodity added',
          change: '0101000000',
        })
      end
    end

    context 'when record is an update operation for a non-declarable commodity' do
      before do
        allow(goods_nomenclature).to receive_messages(operation: :update, declarable?: false)
      end

      it 'returns analysis for non-declarable commodities on update' do
        result = instance.analyze

        expect(result).to eq({
          type: 'GoodsNomenclature',
          goods_nomenclature_sid: goods_nomenclature.goods_nomenclature_sid,
          date_of_effect: date,
          description: 'Commodity added',
          change: '0101000000',
        })
      end
    end
  end
end
