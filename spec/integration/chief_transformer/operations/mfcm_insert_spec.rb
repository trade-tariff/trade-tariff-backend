require 'rails_helper'

describe ChiefTransformer::Processor::MfcmInsert do
  let(:sample_operation_date) { Date.new(2013, 8, 5) }

  before(:all) { preload_standing_data }

  after(:all)  { clear_standing_data }

  describe '#process' do
    context 'mfcm has associated tame' do
      context 'tame has associated tamfs' do
        let(:chief_update) do
          create :chief_update, :applied, issue_date: sample_operation_date
        end

        let!(:measure_type_coe) { create :measure_type, measure_type_id: 'COE', validity_start_date: Date.new(1972, 1, 1) }

        let!(:iq) { create(:geographical_area, geographical_area_id: 'IQ', geographical_area_sid: -2, validity_start_date: DateTime.parse('1975-07-18 00:00:00')) }

        let!(:mfcm) { create(:mfcm, :with_goods_nomenclature, :prohibition, amend_indicator: 'I', fe_tsmp: DateTime.parse('2006-07-24 08:45:00'), msrgp_code: 'HO', msr_type: 'CON', tar_msr_no: '12113000', cmdty_code: '1211300000', origin: chief_update.filename) }
        let!(:tame) { create(:tame, :prohibition, amend_indicator: 'I', fe_tsmp: DateTime.parse('2006-07-24 08:45:00'), msrgp_code: 'HO', msr_type: 'CON', tar_msr_no: '12113000', origin: chief_update.filename) }
        let!(:tamf) { create(:tamf, :prohibition, amend_indicator: 'I', fe_tsmp: DateTime.parse('2006-07-24 08:45:00'), msrgp_code: 'HO', msr_type: 'CON', tar_msr_no: '12113000', cntry_orig: 'IQ', origin: chief_update.filename) }

        let!(:geographical_area) { create :geographical_area, :fifteen_years, :erga_omnes, geographical_area_sid: 400 }

        before do
          ChiefTransformer::Processor::MfcmInsert.new(mfcm).process
        end

        it 'creates excise measure for 0101010100' do
          expect(
            Measure::Operation.where(
              goods_nomenclature_item_id: '1211300000',
              national: true,
              measure_type_id: 'COE',
              operation: 'C',
              operation_date: sample_operation_date,
            ).one?,
          ).to be_truthy
        end

        it 'creates Measure component for P&R measure' do
          measure = Measure.national.first

          expect(
            MeasureCondition::Operation.where(
              measure_sid: measure.measure_sid,
              operation: 'C',
              operation_date: sample_operation_date,
            ).count,
          ).to eq 3
        end
      end

      context 'tame has no associated tamfs' do
        let(:chief_update) do
          create :chief_update, :applied, issue_date: sample_operation_date
        end

        let!(:mfcm) do
          create(:mfcm, :with_goods_nomenclature,
                 amend_indicator: 'I',
                 fe_tsmp: DateTime.parse('2007-11-15 11:00:00'),
                 msrgp_code: 'VT',
                 msr_type: 'S',
                 tty_code: '813',
                 cmdty_code: '0101010100',
                 origin: chief_update.filename)
        end

        let!(:tame) do
          create(:tame, amend_indicator: 'I',
                        fe_tsmp: DateTime.parse('2007-11-15 11:00:00'),
                        msrgp_code: 'VT',
                        msr_type: 'S',
                        tty_code: '813',
                        adval_rate: 15.000,
                        origin: chief_update.filename)
        end

        let!(:geographical_area) { create :geographical_area, :fifteen_years, :erga_omnes }

        before do
          ChiefTransformer::Processor::MfcmInsert.new(mfcm).process
        end

        it 'creates VAT Standard Measure for 0101010100' do
          expect(
            Measure::Operation.where(
              goods_nomenclature_item_id: '0101010100',
              national: true,
              measure_type_id: 'VTS',
              operation: 'C',
              operation_date: sample_operation_date,
            ).one?,
          ).to be_truthy
        end

        it 'creates Measure component with duty rate of 15 for the VAT Measure' do
          expect(
            MeasureComponent::Operation.where(
              duty_amount: 15.0,
              operation: 'C',
              operation_date: sample_operation_date,
            ).one?,
          ).to be_truthy
        end

        it 'create Footnote association for the VAT measure' do
          measure = Measure.national.first

          expect(
            FootnoteAssociationMeasure::Operation.where(
              measure_sid: measure.measure_sid,
              operation: 'C',
              operation_date: sample_operation_date,
            ).one?,
          ).to be_truthy
        end
      end
    end

    context 'MFCM has no associated TAMEs' do
      let(:chief_update) do
        create :chief_update, :applied, issue_date: sample_operation_date
      end

      let!(:mfcm) { create(:mfcm, :with_goods_nomenclature, :prohibition, amend_indicator: 'I', fe_tsmp: DateTime.parse('2006-07-24 08:45:00'), msrgp_code: 'HO', msr_type: 'CON', tar_msr_no: '12113000', cmdty_code: '1211300000', origin: chief_update.filename) }

      before do
        ChiefTransformer::Processor::MfcmInsert.new(mfcm).process
      end

      specify 'no measures get created' do
        expect(Measure.count).to eq 0
      end
    end
  end
end
