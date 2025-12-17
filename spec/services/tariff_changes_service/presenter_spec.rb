RSpec.describe TariffChangesService::Presenter do
  let(:goods_nomenclature) { create(:commodity, :declarable, validity_start_date: Date.new(2024, 1, 1)) }
  let!(:measure_type) { create(:measure_type, trade_movement_code: 0) }
  let!(:measure) { create(:measure, measure_type:, measure_type_id: measure_type.measure_type_id, goods_nomenclature:) }
  let(:geo_area) { create(:geographical_area, :with_description, geographical_area_id: 'FR') }
  let(:tariff_change) do
    create(:tariff_change,
           type: 'Measure',
           object_sid: measure.measure_sid,
           goods_nomenclature_sid: goods_nomenclature.goods_nomenclature_sid,
           goods_nomenclature_item_id: goods_nomenclature.goods_nomenclature_item_id,
           metadata: {
             'measure' => {
               'measure_type_id' => measure_type.measure_type_id,
               'trade_movement_code' => measure_type.trade_movement_code,
               'geographical_area_id' => geo_area.geographical_area_id,
               'excluded_geographical_area_ids' => [],
             },
           })
  end
  let(:geo_area_cache) { { geo_area.geographical_area_id => geo_area } }
  let(:presenter) { described_class.new(tariff_change, geo_area_cache) }

  before do
    allow(tariff_change).to receive_messages(
      goods_nomenclature: goods_nomenclature,
      measure: measure,
    )
  end

  describe '#type' do
    it 'returns the type of the tariff change' do
      result = presenter.type
      expect(result).to eq('Measure')
    end

    context 'when type is GoodsNomenclatureDescription' do
      before do
        allow(tariff_change).to receive_messages(type: 'GoodsNomenclatureDescription')
      end

      it 'modifies the type' do
        result = presenter.type
        expect(result).to eq('Commodity Description')
      end
    end
  end

  describe '#commodity_description' do
    let(:goods_nomenclature_description) { instance_double(GoodsNomenclatureDescription, csv_formatted_description: 'Live horses, asses, mules and hinnies') }

    before do
      allow(TimeMachine).to receive(:at).and_yield
      allow(goods_nomenclature).to receive(:goods_nomenclature_description).and_return(goods_nomenclature_description)
    end

    it 'returns the CSV formatted description' do
      result = presenter.commodity_description
      expect(result).to eq('Live horses, asses, mules and hinnies')
    end

    it 'calls TimeMachine with the commodity validity_start_date' do
      presenter.commodity_description
      expect(TimeMachine).to have_received(:at).with(goods_nomenclature.validity_start_date)
    end

    context 'when goods_nomenclature_description is not available' do
      before do
        allow(goods_nomenclature).to receive(:goods_nomenclature_description).and_return(nil)
      end

      it 'raises an error when trying to call csv_formatted_description on nil' do
        expect { presenter.commodity_description }.to raise_error(NoMethodError)
      end
    end
  end

  describe '#measure_type' do
    context 'when measure_type_id is blank' do
      let(:tariff_change) do
        create(:tariff_change,
               type: 'Measure',
               goods_nomenclature_sid: goods_nomenclature.goods_nomenclature_sid,
               goods_nomenclature_item_id: goods_nomenclature.goods_nomenclature_item_id,
               metadata: { 'measure' => {} })
      end

      it 'returns N/A' do
        result = presenter.measure_type
        expect(result).to eq('N/A')
      end
    end

    context 'when measure_type_id is empty string' do
      let(:tariff_change) do
        create(:tariff_change,
               type: 'Measure',
               goods_nomenclature_sid: goods_nomenclature.goods_nomenclature_sid,
               goods_nomenclature_item_id: goods_nomenclature.goods_nomenclature_item_id,
               metadata: { 'measure' => { 'measure_type_id' => '' } })
      end

      it 'returns N/A for empty string' do
        result = presenter.measure_type
        expect(result).to eq('N/A')
      end
    end

    context 'when measure is present' do
      let(:tariff_change) do
        create(:tariff_change,
               type: 'Measure',
               object_sid: measure.measure_sid,
               goods_nomenclature_sid: goods_nomenclature.goods_nomenclature_sid,
               goods_nomenclature_item_id: goods_nomenclature.goods_nomenclature_item_id,
               metadata: {
                 'measure' => {
                   'measure_type_id' => measure_type.measure_type_id,
                   'trade_movement_code' => measure_type.trade_movement_code,
                   'geographical_area_id' => measure.geographical_area_id,
                   'excluded_geographical_area_ids' => [],
                 },
               })
      end
      let(:presenter) { described_class.new(tariff_change, geo_area_cache) }

      before do
        allow(measure).to receive(:measure_type).and_return(measure_type)
        allow(measure_type).to receive(:description).and_return('Third country duty')
        allow(tariff_change).to receive(:measure).and_return(measure)
      end

      it 'returns the measure type description' do
        result = presenter.measure_type
        expect(result).to eq('Third country duty')
      end
    end

    context 'when measure type has no description' do
      let(:tariff_change) do
        create(:tariff_change,
               type: 'Measure',
               object_sid: measure.measure_sid,
               goods_nomenclature_sid: goods_nomenclature.goods_nomenclature_sid,
               goods_nomenclature_item_id: goods_nomenclature.goods_nomenclature_item_id,
               metadata: {
                 'measure' => {
                   'measure_type_id' => measure_type.measure_type_id,
                   'trade_movement_code' => measure_type.trade_movement_code,
                   'geographical_area_id' => measure.geographical_area_id,
                   'excluded_geographical_area_ids' => [],
                 },
               })
      end
      let(:presenter) { described_class.new(tariff_change, geo_area_cache) }

      before do
        allow(measure).to receive(:measure_type).and_return(measure_type)
        allow(measure_type).to receive(:description).and_return(nil)
        allow(tariff_change).to receive(:measure).and_return(measure)
      end

      it 'returns nil' do
        result = presenter.measure_type
        expect(result).to be_nil
      end
    end
  end

  describe '#import_export' do
    context 'when trade_movement_code is nil' do
      let(:tariff_change) do
        create(:tariff_change,
               type: 'Measure',
               goods_nomenclature_sid: goods_nomenclature.goods_nomenclature_sid,
               goods_nomenclature_item_id: goods_nomenclature.goods_nomenclature_item_id,
               metadata: { 'measure' => {} })
      end

      it 'returns N/A for nil' do
        result = presenter.import_export
        expect(result).to eq('N/A')
      end
    end

    context 'when measure has trade_movement_code 0 (Import)' do
      let(:tariff_change) do
        create(:tariff_change,
               type: 'Measure',
               goods_nomenclature_sid: goods_nomenclature.goods_nomenclature_sid,
               goods_nomenclature_item_id: goods_nomenclature.goods_nomenclature_item_id,
               metadata: { 'measure' => { 'trade_movement_code' => 0 } })
      end

      it 'returns Import' do
        result = presenter.import_export
        expect(result).to eq('Import')
      end
    end

    context 'when measure has trade_movement_code 1 (Export)' do
      let(:tariff_change) do
        create(:tariff_change,
               type: 'Measure',
               goods_nomenclature_sid: goods_nomenclature.goods_nomenclature_sid,
               goods_nomenclature_item_id: goods_nomenclature.goods_nomenclature_item_id,
               metadata: { 'measure' => { 'trade_movement_code' => 1 } })
      end

      it 'returns Export' do
        result = presenter.import_export
        expect(result).to eq('Export')
      end
    end

    context 'when measure has trade_movement_code 2 (Both)' do
      let(:tariff_change) do
        create(:tariff_change,
               type: 'Measure',
               goods_nomenclature_sid: goods_nomenclature.goods_nomenclature_sid,
               goods_nomenclature_item_id: goods_nomenclature.goods_nomenclature_item_id,
               metadata: { 'measure' => { 'trade_movement_code' => 2 } })
      end

      it 'returns Both' do
        result = presenter.import_export
        expect(result).to eq('Both')
      end
    end

    context 'when measure has unknown trade_movement_code' do
      let(:tariff_change) do
        create(:tariff_change,
               type: 'Measure',
               goods_nomenclature_sid: goods_nomenclature.goods_nomenclature_sid,
               goods_nomenclature_item_id: goods_nomenclature.goods_nomenclature_item_id,
               metadata: { 'measure' => { 'trade_movement_code' => 99 } })
      end

      it 'returns empty string' do
        result = presenter.import_export
        expect(result).to eq('')
      end
    end
  end

  describe '#geo_area' do
    context 'when geographical_area_id is blank' do
      let(:tariff_change) do
        create(:tariff_change,
               type: 'Measure',
               goods_nomenclature_sid: goods_nomenclature.goods_nomenclature_sid,
               goods_nomenclature_item_id: goods_nomenclature.goods_nomenclature_item_id,
               metadata: { 'measure' => {} })
      end

      it 'returns N/A for nil' do
        result = presenter.geo_area
        expect(result).to eq('N/A')
      end
    end

    context 'when geographical_area_id is empty string' do
      let(:tariff_change) do
        create(:tariff_change,
               type: 'Measure',
               goods_nomenclature_sid: goods_nomenclature.goods_nomenclature_sid,
               goods_nomenclature_item_id: goods_nomenclature.goods_nomenclature_item_id,
               metadata: { 'measure' => { 'geographical_area_id' => '' } })
      end

      it 'returns N/A for empty string' do
        result = presenter.geo_area
        expect(result).to eq('N/A')
      end
    end

    context 'when geo_area is present' do
      before do
        allow(geo_area.geographical_area_description).to receive(:description).and_return('France')
      end

      it 'returns formatted geo area with description and id' do
        result = presenter.geo_area
        expect(result).to eq('France (FR)')
      end

      context 'when geo_area is erga_omnes' do
        let(:geo_area) { create(:geographical_area, :erga_omnes, :with_description) }
        let(:tariff_change) do
          create(:tariff_change,
                 type: 'Measure',
                 goods_nomenclature_sid: goods_nomenclature.goods_nomenclature_sid,
                 goods_nomenclature_item_id: goods_nomenclature.goods_nomenclature_item_id,
                 metadata: {
                   'measure' => {
                     'geographical_area_id' => geo_area.geographical_area_id,
                     'excluded_geographical_area_ids' => [],
                   },
                 })
        end
        let(:geo_area_cache) { { geo_area.geographical_area_id => geo_area } }

        before do
          allow(geo_area).to receive(:erga_omnes?).and_return(true)
        end

        it 'returns All countries with the id' do
          result = presenter.geo_area
          expect(result).to eq("All countries (#{geo_area.id})")
        end
      end

      context 'when excluded_geographical_areas are provided' do
        let(:excluded_area_1) { create(:geographical_area, :with_description, geographical_area_id: 'DE') }
        let(:excluded_area_2) { create(:geographical_area, :with_description, geographical_area_id: 'IT') }
        let(:tariff_change) do
          create(:tariff_change,
                 type: 'Measure',
                 goods_nomenclature_sid: goods_nomenclature.goods_nomenclature_sid,
                 goods_nomenclature_item_id: goods_nomenclature.goods_nomenclature_item_id,
                 metadata: {
                   'measure' => {
                     'geographical_area_id' => geo_area.geographical_area_id,
                     'excluded_geographical_area_ids' => [excluded_area_1.geographical_area_id, excluded_area_2.geographical_area_id],
                   },
                 })
        end
        let(:geo_area_cache) do
          {
            geo_area.geographical_area_id => geo_area,
            excluded_area_1.geographical_area_id => excluded_area_1,
            excluded_area_2.geographical_area_id => excluded_area_2,
          }
        end

        before do
          allow(excluded_area_1.geographical_area_description).to receive(:description).and_return('Germany')
          allow(excluded_area_2.geographical_area_description).to receive(:description).and_return('Italy')
        end

        it 'includes excluded areas in the result' do
          result = presenter.geo_area
          expect(result).to eq('France (FR) excluding Germany, Italy')
        end
      end

      context 'when excluded_geographical_areas is empty' do
        let(:tariff_change) do
          create(:tariff_change,
                 type: 'Measure',
                 goods_nomenclature_sid: goods_nomenclature.goods_nomenclature_sid,
                 goods_nomenclature_item_id: goods_nomenclature.goods_nomenclature_item_id,
                 metadata: {
                   'measure' => {
                     'geographical_area_id' => geo_area.geographical_area_id,
                     'excluded_geographical_area_ids' => [],
                   },
                 })
        end

        it 'does not include excluding clause' do
          result = presenter.geo_area
          expect(result).to eq('France (FR)')
        end
      end
    end

    context 'with complex scenario: erga_omnes with exclusions' do
      let(:geo_area) { create(:geographical_area, :erga_omnes, :with_description) }
      let(:excluded_area) { create(:geographical_area, :with_description, geographical_area_id: 'US') }
      let(:tariff_change) do
        create(:tariff_change,
               type: 'Measure',
               goods_nomenclature_sid: goods_nomenclature.goods_nomenclature_sid,
               goods_nomenclature_item_id: goods_nomenclature.goods_nomenclature_item_id,
               metadata: {
                 'measure' => {
                   'geographical_area_id' => geo_area.geographical_area_id,
                   'excluded_geographical_area_ids' => [excluded_area.geographical_area_id],
                 },
               })
      end
      let(:geo_area_cache) do
        {
          geo_area.geographical_area_id => geo_area,
          excluded_area.geographical_area_id => excluded_area,
        }
      end

      before do
        allow(geo_area).to receive(:erga_omnes?).and_return(true)
        allow(excluded_area.geographical_area_description).to receive(:description).and_return('United States')
      end

      it 'returns All countries with exclusions' do
        result = presenter.geo_area
        expect(result).to eq("All countries (#{geo_area.id}) excluding United States")
      end
    end
  end

  describe '#additional_code' do
    context 'when additional_code is present' do
      let(:tariff_change) do
        create(:tariff_change,
               type: 'Measure',
               goods_nomenclature_sid: goods_nomenclature.goods_nomenclature_sid,
               goods_nomenclature_item_id: goods_nomenclature.goods_nomenclature_item_id,
               metadata: { 'measure' => { 'additional_code' => 'A123: Test additional code' } })
      end

      it 'returns the additional code' do
        result = presenter.additional_code
        expect(result).to eq('A123: Test additional code')
      end
    end

    context 'when additional_code is blank' do
      let(:tariff_change) do
        create(:tariff_change,
               type: 'Measure',
               goods_nomenclature_sid: goods_nomenclature.goods_nomenclature_sid,
               goods_nomenclature_item_id: goods_nomenclature.goods_nomenclature_item_id,
               metadata: { 'measure' => { 'additional_code' => '' } })
      end

      it 'returns N/A' do
        result = presenter.additional_code
        expect(result).to eq('N/A')
      end
    end
  end
end
