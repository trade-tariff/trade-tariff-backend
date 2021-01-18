require 'rails_helper'

describe ChiefTransformer::Processor::TameInsert do
  before(:all) { preload_standing_data }

  after(:all)  { clear_standing_data }

  let(:sample_operation_date) { Date.new(2013, 8, 5) }

  let(:chief_update) do
    create :chief_update, :applied, issue_date: sample_operation_date
  end

  describe '#process' do
    describe 'update existing TAME measure components' do
      let(:sample_date) { DateTime.parse('2008-04-01 00:00:00') }

      context 'TAME has no TAMFs associated' do
        let!(:tame) do
          create(:tame, amend_indicator: 'I',
                        fe_tsmp: sample_date,
                        tar_msr_no: '0101010100',
                        msrgp_code: 'VT',
                        msr_type: 'S',
                        tty_code: '813',
                        adval_rate: 55.000,
                        origin: chief_update.filename)
        end

        let!(:measure) do
          create :measure, :national,
                 validity_start_date: sample_date,
                 validity_end_date: nil,
                 tariff_measure_number: '0101010100',
                 measure_type_id: 'VTS'
        end

        let!(:measure_component) do
          create :measure_component,
                 measure_sid: measure.measure_sid,
                 duty_expression_id: ChiefTransformer::Processor::TameInsert::TAME_DUTY_EXPRESSION_ID,
                 duty_amount: 5
        end

        before { ChiefTransformer::Processor::TameInsert.new(tame).process }

        it 'updates associated measure components duty amount' do
          expect(measure_component.reload.duty_amount).to eq 55
        end
      end

      context 'TAME has TAMFs associated' do
        let!(:iq) { create(:geographical_area, geographical_area_id: 'IQ', geographical_area_sid: -2, validity_start_date: DateTime.parse('1975-07-18 00:00:00')) }

        let!(:ad) { create(:geographical_area, geographical_area_id: 'AD', geographical_area_sid: 140, validity_start_date: DateTime.parse('1975-07-18 00:00:00')) }
        let!(:fo) { create(:geographical_area, geographical_area_id: 'FO', geographical_area_sid: 330, validity_start_date: DateTime.parse('1975-07-18 00:00:00')) }
        let!(:no) { create(:geographical_area, geographical_area_id: 'NO', geographical_area_sid: 252, validity_start_date: DateTime.parse('1975-07-18 00:00:00')) }
        let!(:sm) { create(:geographical_area, geographical_area_id: 'SM', geographical_area_sid: 382, validity_start_date: DateTime.parse('1975-07-18 00:00:00')) }
        let!(:is) { create(:geographical_area, geographical_area_id: 'IS', geographical_area_sid: 53, validity_start_date: DateTime.parse('1975-07-18 00:00:00')) }

        let!(:tame) do
          create(:tame, :prohibition,
                 amend_indicator: 'I',
                 fe_tsmp: DateTime.parse('2006-07-24 08:45:00'),
                 msrgp_code: 'EX',
                 msr_type: 'EXF',
                 tty_code: '473',
                 tar_msr_no: '2206008900',
                 origin: chief_update.filename)
        end

        let!(:tamf) do
          create(:tamf, :prohibition,
                 amend_indicator: 'I',
                 fe_tsmp: DateTime.parse('2006-07-24 08:45:00'),
                 msrgp_code: 'EX',
                 msr_type: 'EXF',
                 tty_code: '473',
                 spfc1_rate: 66.66,
                 spfc1_cmpd_uoq: '098',
                 spfc1_uoq: '078',
                 tar_msr_no: '2206008900',
                 cntry_disp: 'D066',
                 origin: chief_update.filename)
        end

        let!(:measure) do
          create :measure, :national,
                 validity_start_date: sample_date,
                 validity_end_date: nil,
                 goods_nomenclature_item_id: '2206008900',
                 tariff_measure_number: '2206008900',
                 measure_type_id: 'DGC'
        end

        let!(:measure_component) do
          create :measure_component,
                 measure_sid: measure.measure_sid,
                 duty_expression_id: ChiefTransformer::Processor::TameInsert::TAME_DUTY_EXPRESSION_ID,
                 duty_amount: 13.71,
                 monetary_unit_code: 'GBP',
                 measurement_unit_code: 'ASV',
                 measurement_unit_qualifier_code: 'X'
        end

        let!(:excluded_ga) do
          create :measure_excluded_geographical_area,
                 measure: measure,
                 measure_sid: measure.measure_sid,
                 geographical_area_sid: iq.geographical_area_sid,
                 excluded_geographical_area: iq.geographical_area_id
        end

        before { ChiefTransformer::Processor::TameInsert.new(tame).process }

        it 'deletes existing measure components' do
          expect(
            MeasureComponent::Operation.where(
              measure_sid: measure.measure_sid,
              operation: 'X',
              operation_date: sample_operation_date,
            ),
          ).to be_truthy
        end

        it 'creates new measure components' do
          expect(measure_component.reload.duty_amount).to eq 66.66
        end

        it 'deletes existing associated geographical areas' do
          expect(
            MeasureExcludedGeographicalArea::Operation.where(
              measure_sid: measure.measure_sid,
              geographical_area_sid: iq.geographical_area_sid,
              operation: 'X',
              operation_date: sample_operation_date,
            ),
          ).to be_truthy
        end

        it 'creates new excluded geographical area associations' do
          expect(
            measure.reload.measure_excluded_geographical_areas.map(&:excluded_geographical_area),
          ).to match_array %w[AD FO NO SM IS]
        end
      end
    end

    describe 'creating new measures' do
      context 'contains relevant MFCMs' do
        let!(:mfcm) do
          create(:mfcm, :with_goods_nomenclature, :prohibition, amend_indicator: 'I', fe_tsmp: DateTime.parse('2008-04-01 00:00:00'), msrgp_code: 'PR', msr_type: 'CVD', tar_msr_no: '2106909829', cmdty_code: '2106909829', origin: chief_update.filename)
        end

        let!(:tame) do
          create(:tame, :prohibition,
                 amend_indicator: 'I',
                 fe_tsmp: DateTime.parse('2008-05-01 00:00:00'),
                 msrgp_code: 'PR',
                 msr_type: 'CVD',
                 tar_msr_no: '2106909829',
                 origin: chief_update.filename)
        end

        let!(:geographical_area) { create :geographical_area, :fifteen_years, :erga_omnes, geographical_area_sid: 400 }

        before { ChiefTransformer::Processor::TameInsert.new(tame).process }

        it 'creates new P&R measure' do
          expect(
            Measure.national.where(
              measure_type_id: 'CVD',
              operation_date: sample_operation_date,
              operation: 'C',
            ).one?,
          ).to be_truthy
        end
      end

      context 'contains no relevant MFCMs' do
        let(:tame) { create(:tame, :prohibition, amend_indicator: 'I', fe_tsmp: DateTime.parse('2006-07-24 08:45:00'), msrgp_code: 'HO', msr_type: 'CON', tar_msr_no: '12113000') }

        it 'creates no new measures' do
          expect {
            ChiefTransformer::Processor::TameInsert.new(tame).process
          }.not_to change(Measure, :count)
        end
      end
    end
  end
end
