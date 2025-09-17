RSpec.describe DeltaReportService::CommodityDescriptionChanges do
  let(:date) { Date.parse('2024-08-11') }

  let(:goods_nomenclature) { instance_double(GoodsNomenclature, goods_nomenclature_sid: '12345', declarable?: true) }
  let(:goods_nomenclature_description) do
    instance_double(
      GoodsNomenclatureDescription,
      goods_nomenclature: goods_nomenclature,
      goods_nomenclature_sid: '12345',
      description: 'Test description',
      validity_start_date: date,
      operation: :create,
      operation_date: date,
    )
  end
  let(:instance) { described_class.new(goods_nomenclature_description, date) }

  before do
    allow(instance).to receive(:get_changes)
    allow(GoodsNomenclature::Operation).to receive_message_chain(:where, :any?).and_return(false)
  end

  describe '.collect' do
    let(:goods_nomenclature1) { instance_double(GoodsNomenclature, goods_nomenclature_sid: '11111', declarable?: true) }
    let(:goods_nomenclature2) { instance_double(GoodsNomenclature, goods_nomenclature_sid: '22222', declarable?: true) }
    let(:goods_nomenclature_description1) do
      instance_double(
        GoodsNomenclatureDescription,
        goods_nomenclature: goods_nomenclature1,
        goods_nomenclature_sid: '11111',
        operation: :create,
        validity_start_date: date,
      )
    end
    let(:goods_nomenclature_description2) do
      instance_double(
        GoodsNomenclatureDescription,
        goods_nomenclature: goods_nomenclature2,
        goods_nomenclature_sid: '22222',
        operation: :create,
        validity_start_date: date,
      )
    end
    let(:goods_nomenclature_descriptions) { [goods_nomenclature_description1, goods_nomenclature_description2] }

    before do
      allow(GoodsNomenclatureDescription).to receive(:where).and_return(goods_nomenclature_descriptions)
    end

    it 'finds goods nomenclatures for the given date and returns analyzed changes' do
      instance1 = described_class.new(goods_nomenclature_description1, date)
      instance2 = described_class.new(goods_nomenclature_description2, date)

      allow(described_class).to receive(:new).and_return(instance1, instance2)
      allow(instance1).to receive(:analyze).and_return({ type: 'GoodsNomenclatureDescription' })
      allow(instance2).to receive(:analyze).and_return({ type: 'GoodsNomenclatureDescription' })

      result = described_class.collect(date)

      expect(GoodsNomenclatureDescription).to have_received(:where).with(operation_date: date)
      expect(result).to eq([{ type: 'GoodsNomenclatureDescription' }, { type: 'GoodsNomenclatureDescription' }])
    end

    context 'when some records return nil from analyze' do
      it 'filters out nil results with compact' do
        instance1 = described_class.new(goods_nomenclature_description1, date)
        instance2 = described_class.new(goods_nomenclature_description2, date)

        allow(described_class).to receive(:new).and_return(instance1, instance2)
        allow(instance1).to receive(:analyze).and_return({ type: 'GoodsNomenclatureDescription' })
        allow(instance2).to receive(:analyze).and_return(nil)

        result = described_class.collect(date)

        expect(result).to eq([{ type: 'GoodsNomenclatureDescription' }])
      end
    end

    context 'when no goods nomenclature descriptions exist for the date' do
      before do
        allow(GoodsNomenclatureDescription).to receive(:where).and_return([])
      end

      it 'returns an empty array' do
        result = described_class.collect(date)
        expect(result).to eq([])
      end
    end
  end

  describe '#object_name' do
    it 'returns the correct object name' do
      expect(instance.object_name).to eq('Commodity')
    end
  end

  describe '#excluded_columns' do
    it 'returns the expected excluded columns including inherited ones' do
      expected_columns = %i[oid operation operation_date created_at updated_at filename path heading_short_code chapter_short_code]
      expect(instance.excluded_columns).to eq(expected_columns)
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
      allow(goods_nomenclature_description).to receive_messages(
        validity_start_date: date,
        goods_nomenclature_sid: goods_nomenclature.goods_nomenclature_sid,
        description: 'Test description',
      )
      allow(TimeMachine).to receive(:at).with(date).and_yield
    end

    context 'when there are no changes' do
      before { allow(instance).to receive(:no_changes?).and_return(true) }

      it 'returns nil' do
        expect(instance.analyze).to be_nil
      end
    end

    context 'when goods nomenclature is not declarable' do
      before { allow(goods_nomenclature).to receive(:declarable?).and_return(false) }

      it 'returns nil' do
        expect(instance.analyze).to be_nil
      end
    end

    context 'when goods nomenclature is nil' do
      before { allow(goods_nomenclature_description).to receive(:goods_nomenclature).and_return(nil) }

      it 'returns nil' do
        expect(instance.analyze).to be_nil
      end
    end

    context 'when operation is create and GoodsNomenclature::Operation exists for same date' do
      before do
        allow(GoodsNomenclature::Operation).to receive_message_chain(:where, :any?).and_return(true)
      end

      it 'returns nil' do
        expect(instance.analyze).to be_nil
      end
    end

    context 'when changes should be included' do
      it 'returns the correct analysis hash' do
        result = instance.analyze

        expect(result).to eq({
          type: 'GoodsNomenclatureDescription',
          goods_nomenclature_sid: '12345',
          date_of_effect: date,
          description: 'Commodity added',
          change: 'Test description',
        })
      end
    end

    context 'when change is not nil' do
      before { allow(instance).to receive(:change).and_return('updated description') }

      it 'uses the change value instead of record description' do
        result = instance.analyze
        expect(result[:change]).to eq('updated description')
      end
    end

    context 'when an error occurs in TimeMachine block' do
      before do
        allow(TimeMachine).to receive(:at).and_raise(StandardError.new('Test error'))
        allow(Rails.logger).to receive(:error)
        allow(goods_nomenclature_description).to receive(:oid).and_return(123)
      end

      it 'logs the error with object name and OID' do
        expect { instance.analyze }.to raise_error(StandardError, 'Test error')
        expect(Rails.logger).to have_received(:error).with('Error with Commodity OID 123')
      end
    end

    context 'with different operation types' do
      let(:update_goods_nomenclature_description) do
        instance_double(
          GoodsNomenclatureDescription,
          goods_nomenclature: goods_nomenclature,
          goods_nomenclature_sid: '12345',
          description: 'Updated description',
          validity_start_date: date,
          operation: :update,
          operation_date: date,
          previous_record: nil,
        )
      end

      let(:update_instance) { described_class.new(update_goods_nomenclature_description, date) }

      before do
        allow(update_instance).to receive_messages(
          no_changes?: false,
          date_of_effect: date,
          description: 'Commodity updated',
          change: 'updated description',
        )
        allow(TimeMachine).to receive(:at).with(date).and_yield
      end

      it 'handles update operations correctly' do
        result = update_instance.analyze

        expect(result).to include(
          type: 'GoodsNomenclatureDescription',
          description: 'Commodity updated',
          change: 'updated description',
        )
      end
    end
  end
end
