RSpec.describe TariffChangesService::CommodityDescriptionChanges do
  let(:date) { Date.new(2025, 1, 15) }

  # Helper method to create operation records
  def create_operation_record(description, operation_date: date, operation: 'U')
    description.class.operation_klass.create(
      operation_date: operation_date,
      operation: operation,
      goods_nomenclature_sid: description.goods_nomenclature_sid,
      goods_nomenclature_description_period_sid: description.goods_nomenclature_description_period_sid,
      record: description,
    )
  end

  describe '.collect' do
    let(:goods_nomenclature) { create(:commodity, :declarable) }
    let(:updated_description) do
      create(
        :goods_nomenclature_description,
        goods_nomenclature_sid: goods_nomenclature.goods_nomenclature_sid,
        goods_nomenclature_item_id: goods_nomenclature.goods_nomenclature_item_id,
      )
    end

    before do
      # Create operation record that will be returned by .collect
      create_operation_record(updated_description)
    end

    it 'returns analyzed changes for updated goods nomenclature descriptions from the specified date' do
      results = described_class.collect(date)

      expect(results).to be_an(Array)
      expect(results.size).to be >= 1
      expect(results.first).to include(type: 'GoodsNomenclatureDescription')
    end

    it 'filters out nil results from analyze' do
      instance = described_class.new(updated_description, date)
      allow(described_class).to receive(:new).and_return(instance)
      allow(instance).to receive(:no_changes?).and_return(true)

      results = described_class.collect(date)

      expect(results).to be_empty
    end

    it 'only processes goods nomenclature descriptions from the specified operation date' do
      create_operation_record(updated_description, operation_date: date + 1.day)

      results = described_class.collect(date)

      expect(results.size).to eq(1)
    end

    it 'only processes update operations' do
      create_operation_record(updated_description, operation: 'C')

      results = described_class.collect(date)

      expect(results.size).to eq(1)
    end

    context 'with declarable and non-declarable goods nomenclatures' do
      let(:non_declarable_goods_nomenclature) { create(:commodity, :non_declarable) }
      let(:non_declarable_description) do
        create(
          :goods_nomenclature_description,
          goods_nomenclature_sid: non_declarable_goods_nomenclature.goods_nomenclature_sid,
          goods_nomenclature_item_id: non_declarable_goods_nomenclature.goods_nomenclature_item_id,
        )
      end

      it 'only analyzes descriptions for declarable goods nomenclatures' do
        create_operation_record(non_declarable_description)

        results = described_class.collect(date)

        # Should only include the declarable one
        expect(results.size).to eq(1)
        expect(results.first[:type]).to eq('GoodsNomenclatureDescription')
      end
    end

    context 'when goods nomenclature is nil' do
      let(:orphaned_description) do
        create(:goods_nomenclature_description)
      end

      before do
        create_operation_record(orphaned_description)

        # Simulate orphaned record by clearing the goods_nomenclature association
        orphaned_description.goods_nomenclature&.delete
      end

      it 'handles records with nil goods_nomenclature gracefully' do
        expect { described_class.collect(date) }.not_to raise_error
      end

      it 'skips records with nil goods_nomenclature' do
        results = described_class.collect(date)
        # Should only include the valid one, not the orphaned one
        expect(results.size).to eq(1)
      end
    end

    context 'when no descriptions exist for the date' do
      let(:different_date) { date + 5.days }

      it 'returns an empty array' do
        results = described_class.collect(different_date)
        expect(results).to eq([])
      end
    end
  end

  describe 'instance methods' do
    let(:goods_nomenclature) { create(:commodity, :declarable) }
    let!(:record) do
      create(
        :goods_nomenclature_description,
        goods_nomenclature_sid: goods_nomenclature.goods_nomenclature_sid,
        goods_nomenclature_item_id: goods_nomenclature.goods_nomenclature_item_id,
      )
    end
    let(:commodity_description_changes) { described_class.new(record, date) }

    describe '#object_name' do
      it 'returns "GoodsNomenclatureDescription"' do
        expect(commodity_description_changes.object_name).to eq('GoodsNomenclatureDescription')
      end
    end

    describe '#object_sid' do
      it 'returns the goods_nomenclature_description_period_sid of the record' do
        expect(commodity_description_changes.object_sid).to eq(record.goods_nomenclature_description_period_sid)
      end
    end

    describe 'inheritance from BaseChanges' do
      it 'inherits from TariffChangesService::BaseChanges' do
        expect(described_class.superclass).to eq(TariffChangesService::BaseChanges)
      end

      it 'can call inherited methods' do
        # Set up the record to have some changes
        allow(commodity_description_changes).to receive_messages(
          no_changes?: false,
          action: :update,
          date_of_effect: date,
        )

        expect { commodity_description_changes.analyze }.not_to raise_error
      end
    end

    describe 'integration with analyze method' do
      let!(:record) do
        create(
          :goods_nomenclature_description,
          goods_nomenclature_sid: goods_nomenclature.goods_nomenclature_sid,
          goods_nomenclature_item_id: goods_nomenclature.goods_nomenclature_item_id,
          validity_start_date: date,
          validity_end_date: nil,
        )
      end
      let(:commodity_description_changes) { described_class.new(record, date) }

      it 'returns a properly formatted commodity description change analysis' do
        # Set up the record to simulate an update operation with changes
        allow(commodity_description_changes).to receive_messages(
          no_changes?: false,
          action: :update,
          date_of_effect: date,
        )

        result = commodity_description_changes.analyze

        expect(result[:type]).to eq('GoodsNomenclatureDescription')
        expect(result[:object_sid]).to eq(record.goods_nomenclature_description_period_sid)
        expect(result[:goods_nomenclature_sid]).to eq(record.goods_nomenclature_sid)
        expect(result[:action]).to eq(:update)
        expect(result[:validity_start_date]).to eq(date)
        expect(result[:validity_end_date]).to be_nil
      end
    end

    describe 'commodity description specific behavior' do
      context 'when record has commodity description specific attributes' do
        let!(:record) do
          create(
            :goods_nomenclature_description,
            goods_nomenclature_description_period_sid: 54_321,
            goods_nomenclature_sid: 98_765,
          )
        end
        let(:commodity_description_changes) { described_class.new(record, date) }

        it 'correctly identifies the goods_nomenclature_description_period_sid as object_sid' do
          expect(commodity_description_changes.object_sid).to eq(54_321)
        end

        it 'correctly identifies the goods_nomenclature_sid' do
          allow(commodity_description_changes).to receive_messages(
            no_changes?: false,
            action: :update,
            date_of_effect: date,
          )

          result = commodity_description_changes.analyze
          expect(result[:goods_nomenclature_sid]).to eq(98_765)
        end
      end

      context 'when no_changes? returns true' do
        let(:commodity_description_changes) { described_class.new(record, date) }

        before do
          allow(commodity_description_changes).to receive(:no_changes?).and_return(true)
        end

        it 'returns nil when there are no changes' do
          result = commodity_description_changes.analyze
          expect(result).to be_nil
        end
      end

      context 'when an error occurs during analysis' do
        let(:commodity_description_changes) { described_class.new(record, date) }

        before do
          allow(commodity_description_changes).to receive(:no_changes?).and_return(false)
          allow(commodity_description_changes).to receive(:object_sid).and_raise(StandardError.new('Test error'))
          allow(Rails.logger).to receive(:error)
        end

        it 'logs the error with object name and OID and re-raises' do
          expect { commodity_description_changes.analyze }.to raise_error(StandardError, 'Test error')
          expect(Rails.logger).to have_received(:error).with("Error with GoodsNomenclatureDescription OID #{record.oid}")
        end
      end
    end
  end
end
