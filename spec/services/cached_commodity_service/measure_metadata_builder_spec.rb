RSpec.describe CachedCommodityService::MeasureMetadataBuilder do
  subject(:builder) { described_class.new(presented_commodity) }

  let(:actual_date) { Time.zone.today }

  let!(:commodity) { create(:commodity, :with_chapter_and_heading) }

  let(:geographical_area) do
    create(:geographical_area, :country, :with_description, geographical_area_id: 'RO')
  end

  let(:erga_omnes_area) do
    create(:geographical_area, :erga_omnes, :with_description)
  end

  let(:measure_type) do
    create(:measure_type, measure_type_id: '103', trade_movement_code: 0)
  end

  let!(:measure) do
    create(
      :measure,
      :with_measure_conditions,
      :with_base_regulation,
      goods_nomenclature: commodity,
      goods_nomenclature_item_id: commodity.goods_nomenclature_item_id,
      goods_nomenclature_sid: commodity.goods_nomenclature_sid,
      geographical_area_id: geographical_area.geographical_area_id,
      geographical_area_sid: geographical_area.geographical_area_sid,
      measure_type_id: measure_type.measure_type_id,
    )
  end

  let(:measures) { MeasureCollection.new(commodity.reload.applicable_measures, {}).apply_excise_filter }
  let(:presented_commodity) { Api::V2::Commodities::CommodityPresenter.new(commodity, measures) }

  describe '#build' do
    let(:result) { builder.build }

    it 'returns a hash keyed by measure_sid' do
      expect(result.keys).to all(be_a(Integer))
    end

    it 'extracts geographical_area_id' do
      meta = result[measure.measure_sid]
      expect(meta[:geographical_area_id]).to eq('RO')
    end

    it 'extracts import/export classification' do
      meta = result[measure.measure_sid]
      expect(meta[:import]).to be(true)
    end

    it 'extracts measure_type_id' do
      meta = result[measure.measure_sid]
      expect(meta[:measure_type_id]).to eq(measure_type.measure_type_id)
    end

    it 'extracts excluded_geographical_area_ids as an array' do
      meta = result[measure.measure_sid]
      expect(meta[:excluded_geographical_area_ids]).to be_an(Array)
    end

    it 'extracts contained_geographical_area_ids as an array' do
      meta = result[measure.measure_sid]
      expect(meta[:contained_geographical_area_ids]).to be_an(Array)
    end

    it 'extracts boolean fields' do
      meta = result[measure.measure_sid]

      expect(meta).to include(
        erga_omnes: be_in([true, false]),
        national: be_in([true, false, nil]),
        meursing_type: be_in([true, false]),
        third_country: be_in([true, false]),
        zero_mfn: be_in([true, false]),
        trade_remedy: be_in([true, false]),
        meursing: be_in([true, false]),
        vat: be_in([true, false]),
        expresses_unit: be_in([true, false]),
        tariff_preference: be_in([true, false]),
        preferential_quota: be_in([true, false]),
        authorised_use: be_in([true, false]),
        special_nature: be_in([true, false]),
        gsp_or_dcts: be_in([true, false]),
      )
    end

    it 'includes formatted_duty_expression' do
      meta = result[measure.measure_sid]
      expect(meta).to have_key(:formatted_duty_expression)
    end

    it 'includes has_no_additional_code flag' do
      meta = result[measure.measure_sid]
      expect(meta[:has_no_additional_code]).to be_in([true, false])
    end

    context 'with an erga omnes measure' do
      let(:geographical_area) { erga_omnes_area }

      it 'marks erga_omnes as true' do
        meta = result[measure.measure_sid]
        expect(meta[:erga_omnes]).to be true
      end
    end
  end
end
