RSpec.describe TariffChangesService::CommodityChanges do
  let(:date) { Date.new(2025, 1, 15) }

  describe '.collect' do
    let!(:declarable_commodity) { create(:commodity, :declarable, operation_date: date) }

    it 'returns analyzed changes for declarable goods nomenclatures from the specified date' do
      allow(described_class).to receive(:new).and_return(instance_double(described_class, analyze: { type: 'Commodity' }))

      results = described_class.collect(date)

      expect(results).to include({ type: 'Commodity' })
      expect(results.size).to be >= 1
    end

    it 'filters out nil results from analyze' do
      allow(described_class).to receive(:new).and_return(instance_double(described_class, analyze: nil))

      results = described_class.collect(date)

      expect(results).to be_empty
    end

    it 'only processes goods nomenclatures from the specified operation date' do
      allow(GoodsNomenclature).to receive(:where).with(operation_date: date).and_call_original

      described_class.collect(date)

      expect(GoodsNomenclature).to have_received(:where).with(operation_date: date)
    end

    context 'with declarable goods nomenclatures' do
      let!(:non_declarable_commodity) { create(:commodity, operation_date: date) }

      before do
        allow(GoodsNomenclature).to receive(:where).with(operation_date: date).and_return([declarable_commodity, non_declarable_commodity])

        allow(declarable_commodity).to receive(:declarable?).and_return(true)
        allow(non_declarable_commodity).to receive(:declarable?).and_return(false)
      end

      it 'only analyzes declarable goods nomenclatures' do
        allow(described_class).to receive(:new).and_call_original

        described_class.collect(date)

        expect(described_class).to have_received(:new).with(declarable_commodity, date)
        expect(described_class).not_to have_received(:new).with(non_declarable_commodity, date)
      end
    end
  end

  describe 'instance methods' do
    let(:record) { create(:commodity, :declarable, operation_date: date) }
    let(:commodity_changes) { described_class.new(record, date) }

    describe '#object_name' do
      it 'returns "Commodity"' do
        expect(commodity_changes.object_name).to eq('Commodity')
      end
    end

    describe '#object_sid' do
      it 'returns the goods_nomenclature_sid of the record' do
        expect(commodity_changes.object_sid).to eq(record.goods_nomenclature_sid)
      end
    end

    describe '#excluded_columns' do
      it 'includes base excluded columns plus commodity-specific ones' do
        base_excluded = %i[oid operation operation_date created_at updated_at filename]
        commodity_excluded = %i[path heading_short_code chapter_short_code]
        expected = base_excluded + commodity_excluded

        expect(commodity_changes.excluded_columns).to eq(expected)
      end
    end

    describe 'inheritance from BaseChanges' do
      it 'inherits from TariffChangesService::BaseChanges' do
        expect(described_class.superclass).to eq(TariffChangesService::BaseChanges)
      end

      it 'can call inherited methods' do
        allow(commodity_changes).to receive_messages(no_changes?: false, action: 'creation', date_of_effect: date)

        expect { commodity_changes.analyze }.not_to raise_error
      end
    end

    describe 'integration with analyze method' do
      let(:record) do
        create(
          :commodity,
          :declarable,
          operation_date: date,
          validity_start_date: date,
          validity_end_date: nil,
        )
      end

      before do
        allow(record).to receive(:operation).and_return(:create)
      end

      it 'returns a properly formatted commodity change analysis' do
        result = commodity_changes.analyze

        expect(result).to include(
          type: 'Commodity',
          object_sid: record.goods_nomenclature_sid,
          goods_nomenclature_sid: record.goods_nomenclature_sid,
          goods_nomenclature_item_id: record.goods_nomenclature_item_id,
          action: 'creation',
          validity_start_date: date,
          validity_end_date: nil,
        )
      end
    end
  end
end
