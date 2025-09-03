RSpec.describe DeltaReportService::FootnoteAssociationGoodsNomenclatureChanges do
  let(:date) { Date.parse('2024-08-11') }

  let(:goods_nomenclature) { build(:goods_nomenclature, goods_nomenclature_item_id: '0101000000') }
  let(:footnote) { build(:footnote, footnote_id: '001', footnote_type_id: 'TN', oid: '999') }
  let(:footnote_association) do
    build(
      :footnote_association_goods_nomenclature,
      oid: '123',
      footnote_id: footnote.footnote_id,
      footnote_type: footnote.footnote_type_id,
      goods_nomenclature_sid: goods_nomenclature.goods_nomenclature_sid,
      operation_date: date,
    )
  end
  let(:instance) { described_class.new(footnote_association, date) }

  before do
    allow(instance).to receive(:get_changes)
    allow(footnote_association).to receive_messages(
      footnote: footnote,
      goods_nomenclature: goods_nomenclature,
    )
    allow(footnote).to receive(:code).and_return("#{footnote.footnote_type_id}#{footnote.footnote_id}")
  end

  describe '.collect' do
    let(:association1) { build(:footnote_association_goods_nomenclature, oid: 1, operation_date: date) }
    let(:association2) { build(:footnote_association_goods_nomenclature, oid: 2, operation_date: date) }
    let(:associations) { [association1, association2] }

    before do
      allow(FootnoteAssociationGoodsNomenclature).to receive_message_chain(:where, :order).and_return(associations)
    end

    it 'finds footnote association goods nomenclatures for the given date and returns analyzed changes' do
      instance1 = described_class.new(association1, date)
      instance2 = described_class.new(association2, date)

      allow(described_class).to receive(:new).and_return(instance1, instance2)
      allow(instance1).to receive(:analyze).and_return({ type: 'FootnoteAssociationGoodsNomenclature' })
      allow(instance2).to receive(:analyze).and_return({ type: 'FootnoteAssociationGoodsNomenclature' })

      result = described_class.collect(date)

      expect(FootnoteAssociationGoodsNomenclature).to have_received(:where).with(operation_date: date)
      expect(result).to eq([{ type: 'FootnoteAssociationGoodsNomenclature' }, { type: 'FootnoteAssociationGoodsNomenclature' }])
    end

    it 'filters out nil results from analyze' do
      instance1 = described_class.new(association1, date)
      instance2 = described_class.new(association2, date)

      allow(described_class).to receive(:new).and_return(instance1, instance2)
      allow(instance1).to receive(:analyze).and_return({ type: 'FootnoteAssociationGoodsNomenclature' })
      allow(instance2).to receive(:analyze).and_return(nil)

      result = described_class.collect(date)

      expect(result).to eq([{ type: 'FootnoteAssociationGoodsNomenclature' }])
    end
  end

  describe '#object_name' do
    it 'returns the correct object name with footnote code' do
      expect(instance.object_name).to eq('Footnote')
    end
  end

  describe '#analyze' do
    before do
      allow(instance).to receive_messages(
        no_changes?: false,
        date_of_effect: date,
        description: 'Footnote TN001 updated',
        change: nil,
      )
    end

    context 'when there are no changes' do
      before { allow(instance).to receive(:no_changes?).and_return(true) }

      it 'returns nil' do
        expect(instance.analyze).to be_nil
      end
    end

    context 'when record is a create operation and goods nomenclature was created on the same date' do
      before do
        allow(footnote_association).to receive(:operation).and_return(:create)
        allow(goods_nomenclature).to receive(:operation_date).and_return(date)
      end

      it 'returns nil' do
        expect(instance.analyze).to be_nil
      end
    end

    context 'when record is a create operation and footnote was created on the same date' do
      before do
        allow(footnote_association).to receive(:operation).and_return(:create)
        allow(goods_nomenclature).to receive(:operation_date).and_return(date - 1)
        allow(footnote).to receive(:operation_date).and_return(date)
      end

      it 'returns nil' do
        expect(instance.analyze).to be_nil
      end
    end

    context 'when changes should be included' do
      before do
        allow(footnote_association).to receive(:operation).and_return(:update)
        allow(goods_nomenclature).to receive(:operation_date).and_return(date - 1)
        allow(footnote).to receive(:operation_date).and_return(date - 1)
      end

      it 'returns the correct analysis hash' do
        result = instance.analyze

        expect(result).to eq({
          type: 'FootnoteAssociationGoodsNomenclature',
          goods_nomenclature_item_id: goods_nomenclature.goods_nomenclature_item_id,
          description: 'Footnote TN001 updated',
          date_of_effect: date,
          change: footnote.code,
        })
      end
    end

    context 'when change value is present' do
      before do
        allow(footnote_association).to receive(:operation).and_return(:update)
        allow(goods_nomenclature).to receive(:operation_date).and_return(date - 1)
        allow(footnote).to receive(:operation_date).and_return(date - 1)
        allow(instance).to receive(:change).and_return('validity_start_date updated')
      end

      it 'includes the change value in the result' do
        result = instance.analyze
        expect(result[:change]).to eq("#{footnote.code}: validity_start_date updated")
      end
    end

    context 'when record is a create operation but entities were created on different dates' do
      before do
        allow(footnote_association).to receive(:operation).and_return(:create)
        allow(goods_nomenclature).to receive(:operation_date).and_return(date - 1)
        allow(footnote).to receive(:operation_date).and_return(date - 2)
      end

      it 'returns the analysis hash' do
        result = instance.analyze

        expect(result).to eq({
          type: 'FootnoteAssociationGoodsNomenclature',
          goods_nomenclature_item_id: goods_nomenclature.goods_nomenclature_item_id,
          description: 'Footnote TN001 updated',
          date_of_effect: date,
          change: footnote.code,
        })
      end
    end
  end

  describe '#previous_record' do
    let(:instance) { described_class.new(footnote_association, date) }
    let(:previous_footnote_association) { build(:footnote_association_goods_nomenclature) }

    before do
      allow(FootnoteAssociationGoodsNomenclature).to receive(:operation_klass).and_return(FootnoteAssociationGoodsNomenclature)
      allow(FootnoteAssociationGoodsNomenclature).to receive_message_chain(:where, :where, :order, :first)
                         .and_return(previous_footnote_association)
    end

    it 'queries for the previous record by goods_nomenclature_sid, footnote_id, footnote_type and oid' do
      result = instance.previous_record

      expect(result).to eq(previous_footnote_association)
    end

    it 'memoizes the result' do
      instance.previous_record
      instance.previous_record

      expect(FootnoteAssociationGoodsNomenclature).to have_received(:operation_klass).once
    end
  end
end
