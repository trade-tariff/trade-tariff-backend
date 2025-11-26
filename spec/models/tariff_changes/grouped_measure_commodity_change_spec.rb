RSpec.describe TariffChanges::GroupedMeasureCommodityChange do
  subject(:grouped_commodity_change) do
    described_class.new(
      goods_nomenclature_item_id: '1234567890',
      count: 5,
      grouped_measure_change_id: 'import_GB_FR-DE',
    )
  end

  describe 'attributes' do
    it 'has the expected attributes' do
      expect(grouped_commodity_change.goods_nomenclature_item_id).to eq('1234567890')
      expect(grouped_commodity_change.count).to eq(5)
      expect(grouped_commodity_change.grouped_measure_change_id).to eq('import_GB_FR-DE')
    end

    it 'can be initialized with minimal attributes' do
      minimal_change = described_class.new(goods_nomenclature_item_id: '9876543210')
      expect(minimal_change.goods_nomenclature_item_id).to eq('9876543210')
      expect(minimal_change.count).to be_nil
      expect(minimal_change.grouped_measure_change_id).to be_nil
    end
  end

  describe '#id' do
    it 'generates correct id from attributes' do
      expect(grouped_commodity_change.id).to eq('import_GB_FR-DE_1234567890')
    end

    context 'when grouped_measure_change_id is nil' do
      subject(:grouped_commodity_change) do
        described_class.new(
          goods_nomenclature_item_id: '1234567890',
          grouped_measure_change_id: nil,
        )
      end

      it 'generates id with nil prefix' do
        expect(grouped_commodity_change.id).to eq('_1234567890')
      end
    end

    context 'when goods_nomenclature_item_id is nil' do
      subject(:grouped_commodity_change) do
        described_class.new(
          goods_nomenclature_item_id: nil,
          grouped_measure_change_id: 'export_US_',
        )
      end

      it 'generates id with nil suffix' do
        expect(grouped_commodity_change.id).to eq('export_US__')
      end
    end
  end

  describe '#commodity' do
    context 'when commodity is set' do
      let(:goods_nomenclature) { create(:goods_nomenclature, goods_nomenclature_item_id: '1234567890') }

      before do
        grouped_commodity_change.commodity = goods_nomenclature
      end

      it 'returns the set commodity' do
        expect(grouped_commodity_change.commodity).to eq(goods_nomenclature)
        expect(grouped_commodity_change.commodity.goods_nomenclature_item_id).to eq('1234567890')
      end

      it 'returns the commodity_id' do
        expect(grouped_commodity_change.commodity_id).to eq(goods_nomenclature.id)
      end
    end

    context 'when goods nomenclature does not exist' do
      it 'returns nil for non-existent commodity' do
        expect(grouped_commodity_change.commodity).to be_nil
      end
    end

    context 'when goods_nomenclature_item_id is nil' do
      subject(:grouped_commodity_change) do
        described_class.new(goods_nomenclature_item_id: nil)
      end

      it 'returns nil when goods_nomenclature_item_id is nil' do
        expect(grouped_commodity_change.commodity).to be_nil
      end
    end

    context 'when goods_nomenclature_item_id is blank' do
      subject(:grouped_commodity_change) do
        described_class.new(goods_nomenclature_item_id: '')
      end

      it 'returns nil when goods_nomenclature_item_id is blank' do
        expect(grouped_commodity_change.commodity).to be_nil
      end
    end
  end

  describe '#grouped_measure_change' do
    context 'when grouped_measure_change_id is present' do
      it 'returns a GroupedMeasureChange object created from the id' do
        result = grouped_commodity_change.grouped_measure_change

        expect(result).to be_a(TariffChanges::GroupedMeasureChange)
        expect(result.trade_direction).to eq('import')
        expect(result.geographical_area_id).to eq('GB')
        expect(result.excluded_geographical_area_ids).to eq(%w[FR DE])
      end

      it 'memoizes the result' do
        allow(TariffChanges::GroupedMeasureChange).to receive(:from_id).and_call_original

        2.times { grouped_commodity_change.grouped_measure_change }

        expect(TariffChanges::GroupedMeasureChange).to have_received(:from_id).once
      end
    end

    context 'when grouped_measure_change_id is nil' do
      subject(:grouped_commodity_change) do
        described_class.new(
          goods_nomenclature_item_id: '1234567890',
          grouped_measure_change_id: nil,
        )
      end

      it 'returns nil' do
        expect(grouped_commodity_change.grouped_measure_change).to be_nil
      end
    end

    context 'when grouped_measure_change_id is blank' do
      subject(:grouped_commodity_change) do
        described_class.new(
          goods_nomenclature_item_id: '1234567890',
          grouped_measure_change_id: '',
        )
      end

      it 'returns a GroupedMeasureChange with empty parts' do
        result = grouped_commodity_change.grouped_measure_change

        expect(result).to be_a(TariffChanges::GroupedMeasureChange)
        expect(result.trade_direction).to be_nil
        expect(result.geographical_area_id).to be_nil
        expect(result.excluded_geographical_area_ids).to eq([])
      end
    end
  end

  describe 'ActiveModel integration' do
    it 'includes ActiveModel::Model' do
      expect(described_class.ancestors).to include(ActiveModel::Model)
    end

    it 'includes ActiveModel::Attributes' do
      expect(described_class.ancestors).to include(ActiveModel::Attributes)
    end

    it 'responds to ActiveModel methods' do
      expect(grouped_commodity_change).to respond_to(:valid?)
      expect(grouped_commodity_change).to respond_to(:errors)
    end

    it 'can be validated' do
      expect(grouped_commodity_change.valid?).to be true
      expect(grouped_commodity_change.errors).to be_empty
    end
  end

  describe 'associations' do
    it 'establishes the bidirectional relationship correctly' do
      grouped_measure_change = TariffChanges::GroupedMeasureChange.new(
        trade_direction: 'import',
        geographical_area_id: 'GB',
        excluded_geographical_area_ids: %w[FR DE],
      )

      commodity_change = grouped_measure_change.add_commodity_change(
        goods_nomenclature_item_id: '1234567890',
        count: 3,
      )

      expect(commodity_change.grouped_measure_change_id).to eq(grouped_measure_change.id)
      expect(commodity_change.grouped_measure_change).to be_a(TariffChanges::GroupedMeasureChange)
      expect(commodity_change.grouped_measure_change.trade_direction).to eq('import')
    end
  end

  describe '#measure_changes' do
    let(:date) { Date.parse('2023-01-15') }
    let(:geographical_area) { create(:geographical_area, geographical_area_id: 'GB') }
    let(:excluded_area_1) { create(:geographical_area, geographical_area_id: 'FR') }
    let(:excluded_area_2) { create(:geographical_area, geographical_area_id: 'DE') }
    let(:import_measure_type) { create(:measure_type, :import) }
    let(:export_measure_type) { create(:measure_type, :export) }

    context 'when grouped_measure_change is nil' do
      subject(:grouped_commodity_change) do
        described_class.new(
          goods_nomenclature_item_id: '1234567890',
          grouped_measure_change_id: nil,
        )
      end

      it 'returns an empty hash' do
        result = grouped_commodity_change.measure_changes(date)
        expect(result).to eq({})
      end
    end

    context 'when grouped_measure_change exists' do
      let(:measure_1) do
        create(:measure,
               measure_sid: 100,
               measure_type_id: import_measure_type.measure_type_id,
               geographical_area_id: 'GB',
               geographical_area_sid: geographical_area.geographical_area_sid)
      end

      let(:measure_2) do
        create(:measure,
               measure_sid: 200,
               measure_type_id: export_measure_type.measure_type_id,
               geographical_area_id: 'GB',
               geographical_area_sid: geographical_area.geographical_area_sid)
      end

      let(:measure_3) do
        create(:measure,
               measure_sid: 300,
               measure_type_id: import_measure_type.measure_type_id,
               geographical_area_id: 'US')
      end

      before do
        geographical_area
        excluded_area_1
        excluded_area_2
        import_measure_type
        export_measure_type

        create(:measure_excluded_geographical_area,
               measure_sid: measure_1.measure_sid,
               excluded_geographical_area: 'FR')
        create(:measure_excluded_geographical_area,
               measure_sid: measure_1.measure_sid,
               excluded_geographical_area: 'DE')

        create(:tariff_change,
               type: 'Measure',
               object_sid: measure_1.measure_sid,
               operation_date: date,
               goods_nomenclature_item_id: '1234567890')

        create(:tariff_change,
               type: 'Measure',
               object_sid: measure_2.measure_sid,
               operation_date: date,
               goods_nomenclature_item_id: '1234567890')

        create(:tariff_change,
               type: 'Measure',
               object_sid: measure_3.measure_sid,
               operation_date: date,
               goods_nomenclature_item_id: '1234567890')
      end

      context 'for import measures with specific geographical area and excluded areas' do
        subject(:grouped_commodity_change) do
          described_class.new(
            goods_nomenclature_item_id: '1234567890',
            grouped_measure_change_id: 'import_GB_FR-DE',
          )
        end

        it 'returns tariff changes grouped by measure type' do
          result = grouped_commodity_change.measure_changes(date)

          expect(result).to be_a(Hash)
          expect(result.keys).to contain_exactly(import_measure_type.description)
          expect(result[import_measure_type.description]).to all(be_a(Hash))
          expect(result[import_measure_type.description]).to all(include(:date_of_effect, :change_type))
        end

        it 'does not include export measures' do
          result = grouped_commodity_change.measure_changes(date)

          expect(result[export_measure_type.measure_type_id]).to be_nil
        end

        it 'does not include measures with different geographical areas' do
          result = grouped_commodity_change.measure_changes(date)

          expect(result).to be_a(Hash)
          expect(result.values.flatten).to all(be_a(Hash).and(include(:date_of_effect, :change_type)))
        end
      end

      context 'for export measures' do
        subject(:grouped_commodity_change) do
          described_class.new(
            goods_nomenclature_item_id: '1234567890',
            grouped_measure_change_id: 'export_GB_',
          )
        end

        it 'returns only export measures' do
          result = grouped_commodity_change.measure_changes(date)

          expect(result.keys).to contain_exactly(export_measure_type.description)
          expect(result[export_measure_type.description]).to all(be_a(Hash))
          expect(result[export_measure_type.description]).to all(include(:date_of_effect, :change_type))
        end
      end

      context 'when no matching measures exist' do
        subject(:grouped_commodity_change) do
          described_class.new(
            goods_nomenclature_item_id: '1234567890',
            grouped_measure_change_id: 'import_CA_',
          )
        end

        it 'returns an empty hash' do
          result = grouped_commodity_change.measure_changes(date)

          expect(result).to eq({})
        end
      end

      context 'for import measures with US geographical area and no excluded areas' do
        subject(:grouped_commodity_change) do
          described_class.new(
            goods_nomenclature_item_id: '1234567890',
            grouped_measure_change_id: 'import_US_',
          )
        end

        it 'returns tariff changes for US import measures' do
          result = grouped_commodity_change.measure_changes(date)

          expect(result).to be_a(Hash)
          expect(result.keys).to contain_exactly(import_measure_type.description)
          expect(result[import_measure_type.description]).to all(be_a(Hash))
          expect(result[import_measure_type.description]).to all(include(:date_of_effect, :change_type))
        end
      end

      context 'when filtering by different commodity code' do
        subject(:grouped_commodity_change) do
          described_class.new(
            goods_nomenclature_item_id: '9999999999',
            grouped_measure_change_id: 'import_GB_FR-DE',
          )
        end

        it 'returns empty hash when no tariff changes match the commodity code' do
          result = grouped_commodity_change.measure_changes(date)

          expect(result).to eq({})
        end
      end

      context 'when filtering by different date' do
        subject(:grouped_commodity_change) do
          described_class.new(
            goods_nomenclature_item_id: '1234567890',
            grouped_measure_change_id: 'import_GB_FR-DE',
          )
        end

        let(:different_date) { Date.parse('2023-01-16') }

        it 'returns empty hash when no tariff changes match the date' do
          result = grouped_commodity_change.measure_changes(different_date)

          expect(result).to eq({})
        end
      end
    end

    context 'with multiple measure types' do
      subject(:grouped_commodity_change) do
        described_class.new(
          goods_nomenclature_item_id: '1234567890',
          grouped_measure_change_id: 'import_GB_',
        )
      end

      let(:import_measure_type_2) { create(:measure_type, :import, measure_type_id: '999') }
      let(:measure_4) do
        create(:measure,
               measure_sid: 400,
               measure_type_id: import_measure_type_2.measure_type_id,
               geographical_area_id: 'GB',
               geographical_area_sid: geographical_area.geographical_area_sid)
      end

      before do
        geographical_area
        import_measure_type
        import_measure_type_2

        create(:tariff_change,
               type: 'Measure',
               object_sid: measure_4.measure_sid,
               operation_date: date,
               goods_nomenclature_item_id: '1234567890')

        measure_without_exclusions = create(:measure,
                                            measure_sid: 500,
                                            measure_type_id: import_measure_type.measure_type_id,
                                            geographical_area_id: 'GB',
                                            geographical_area_sid: geographical_area.geographical_area_sid)

        create(:tariff_change,
               type: 'Measure',
               object_sid: measure_without_exclusions.measure_sid,
               operation_date: date,
               goods_nomenclature_item_id: '1234567890')
      end

      it 'groups measures correctly by measure type' do
        result = grouped_commodity_change.measure_changes(date)

        expect(result).to be_a(Hash)
        expect(result.keys).to contain_exactly(import_measure_type.description, import_measure_type_2.description)

        expect(result[import_measure_type.description]).to all(be_a(Hash))
        expect(result[import_measure_type_2.description]).to all(be_a(Hash))

        expect(result.values.flatten).to all(include(:date_of_effect, :change_type))
      end
    end
  end
end
