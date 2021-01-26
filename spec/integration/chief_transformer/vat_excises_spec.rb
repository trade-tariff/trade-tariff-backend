require 'rails_helper'
require 'chief_transformer'

describe 'CHIEF: VAT and Excises' do
  before(:all) do
    preload_standing_data
    create :base_regulation, base_regulation_id: 'IYY99990',
                             validity_start_date: Date.new(1971, 12, 31)
  end

  after(:all) { clear_standing_data }

  # NOTE: We need to do a time travel because some factories are creating
  # records with validity end/start date 15/20 years ago.
  before { travel_to Date.new(2020, 1, 1) }

  after { travel_back }

  # VAT/EXCISE measure types
  # Create Measure types used in transformations, so that validations would pass.
  # Faster than loading static_national_data.sql
  let!(:measure_type_vts) { create :measure_type, measure_type_id: 'VTS', validity_start_date: Date.new(1972, 1, 1) }
  let!(:measure_type_vtz) { create :measure_type, measure_type_id: 'VTZ', validity_start_date: Date.new(1972, 1, 1) }
  let!(:measure_type_egj) { create :measure_type, measure_type_id: 'EGJ', validity_start_date: Date.new(1972, 1, 1) }
  let!(:measure_type_daa) { create :measure_type, measure_type_id: 'DAA', validity_start_date: Date.new(1972, 1, 1) }

  context 'TAME Initial Load Scenario 1: VAT measures' do
    let!(:tame1) { create(:tame, amend_indicator: 'I', fe_tsmp: DateTime.parse('2005-01-01 11:00:00'), msrgp_code: 'VT', msr_type: 'S', tty_code: '813', adval_rate: BigDecimal('17.5')) }
    let!(:tame2) { create(:tame, amend_indicator: 'I', fe_tsmp: DateTime.parse('2005-01-01 00:00:00'), msrgp_code: 'VT', msr_type: 'A', tty_code: '813', adval_rate: BigDecimal('5')) }
    let!(:tame3) { create(:tame, amend_indicator: 'I', fe_tsmp: DateTime.parse('2007-10-01 00:00:00'), msrgp_code: 'VT', msr_type: 'Z', tty_code: 'B00') }
    let!(:tame4) { create(:tame, amend_indicator: 'I', fe_tsmp: DateTime.parse('2007-10-01 00:00:00'), msrgp_code: 'VT', msr_type: 'E', tty_code: 'B00') }

    let!(:mfcm1) { create(:mfcm, :with_goods_nomenclature, amend_indicator: 'I', fe_tsmp: DateTime.parse('2005-01-01 11:00:00'), msrgp_code: 'VT', msr_type: 'S', tty_code: '813', cmdty_code: '0101010100') }
    let!(:mfcm2) { create(:mfcm, :with_goods_nomenclature, amend_indicator: 'I', fe_tsmp: DateTime.parse('2006-06-01 00:00:00'), msrgp_code: 'VT', msr_type: 'S', tty_code: '813', le_tsmp: DateTime.parse('2008-12-31 23:14:10'), cmdty_code: '0202020200') }
    let!(:mfcm3) { create(:mfcm, :with_goods_nomenclature, amend_indicator: 'I', fe_tsmp: DateTime.parse('2007-11-15 11:00:00'), msrgp_code: 'VT', msr_type: 'A', tty_code: '813', cmdty_code: '0303030300') }
    let!(:mfcm4) { create(:mfcm, :with_goods_nomenclature, amend_indicator: 'I', fe_tsmp: DateTime.parse('2007-10-01 00:00:00'), msrgp_code: 'VT', msr_type: 'Z', tty_code: 'B00', cmdty_code: '0404040400') }

    let!(:geographical_area) { create :geographical_area, :twenty_years, :erga_omnes }

    before do
      ChiefTransformer.instance.invoke(:initial_load)
    end

    it 'creates measure for 0101010100' do
      m = Measure.where(goods_nomenclature_item_id: '0101010100', validity_start_date: DateTime.parse('2005-01-01 11:00:00')).take
      expect(m.measure_components.first.duty_amount).to eq 17.5
    end

    it 'creates measure for 0202020200' do
      m = Measure.where(goods_nomenclature_item_id: '0202020200', validity_start_date: DateTime.parse('2006-06-01 00:00:00'), validity_end_date: DateTime.parse('2008-12-31 23:14:10')).take
      expect(m.measure_components.first.duty_amount).to eq 17.5
    end

    it 'creates measure for 0303030300' do
      m = Measure.where(goods_nomenclature_item_id: '0303030300', validity_start_date: DateTime.parse('2007-11-15 11:00:00')).take
      expect(m.measure_components.first.duty_amount).to eq 5
    end

    it 'creates measure for 0404040400' do
      m = Measure.where(goods_nomenclature_item_id: '0404040400', validity_start_date: DateTime.parse('2007-10-01 00:00:00')).take
      expect(m.measure_components.first.duty_amount).to eq 0
    end
  end

  context 'TAME Initial Load Scenario 2: VAT seasonal goods and pseudo commodity codes' do
    let!(:tame1) { create(:tame, amend_indicator: 'I', fe_tsmp: DateTime.parse('2005-01-01 11:00:00'), msrgp_code: 'VT', msr_type: 'S', tty_code: '813', adval_rate: BigDecimal('17.5')) }

    let!(:mfcm1) { build(:mfcm, :with_goods_nomenclature, amend_indicator: 'I', fe_tsmp: DateTime.parse('2005-01-01 11:00:00'), msrgp_code: 'VT', msr_type: 'S', tty_code: '813', cmdty_code: '01010101A00') }
    let!(:mfcm2) { create(:mfcm, :with_goods_nomenclature, amend_indicator: 'I', fe_tsmp: DateTime.parse('2006-06-01 00:00:00'), msrgp_code: 'VT', msr_type: 'S', tty_code: '813', cmdty_code: '0101010100') }
    let!(:mfcm3) { build(:mfcm, :with_goods_nomenclature, amend_indicator: 'I', fe_tsmp: DateTime.parse('2006-06-01 00:00:00'), msrgp_code: 'VT', msr_type: 'S', tty_code: '813', cmdty_code: '9920990000') }

    let!(:geographical_area) { create :geographical_area, :fifteen_years, :erga_omnes }

    it 'does not save invalid mfcm records' do
      expect(mfcm1).not_to be_valid
      expect(mfcm3).not_to be_valid
    end

    it 'creates the following measures' do
      ChiefTransformer.instance.invoke(:initial_load)
      m = Measure.where(goods_nomenclature_item_id: '0101010100', validity_start_date: DateTime.parse('2006-06-01 00:00:00')).take
      expect(m.measure_components.first.duty_amount).to eq 17.5
    end
  end

  context 'TAMF Initial Load Scenario 1: Excise measures' do
    # Excise measures with no duty amount specified in CHIEF will results in a Taric measure with duty amount set to 0%.
    # The start and end date of the Taric measure is set to the minimum common interval of the related MFCM, TAME and TAMF records.

    let!(:tame1) { create(:tame, amend_indicator: 'I', fe_tsmp: DateTime.parse('2005-01-01 11:00:00'), msrgp_code: 'EX', msr_type: 'EXF', tty_code: '423') }
    let!(:tame2) { create(:tame, amend_indicator: 'I', fe_tsmp: DateTime.parse('2005-01-01 00:00:00'), msrgp_code: 'EX', msr_type: 'EXF', tty_code: '611') }
    let!(:tame3) { create(:tame, amend_indicator: 'I', fe_tsmp: DateTime.parse('2007-10-01 00:00:00'), msrgp_code: 'EX', msr_type: 'EXL', tty_code: '520', le_tsmp: DateTime.parse('2007-12-31 23:50:00')) }
    let!(:tame4) { create(:tame, amend_indicator: 'I', fe_tsmp: DateTime.parse('2005-01-01 00:00:00'), msrgp_code: 'EX', msr_type: 'EXF', tty_code: '551') }

    let!(:tamf1) { create(:tamf, amend_indicator: 'I', fe_tsmp: DateTime.parse('2005-01-01 11:00:00'), msrgp_code: 'EX', msr_type: 'EXF', tty_code: '423', spfc1_rate: BigDecimal('1.7799')) }
    let!(:tamf2) { create(:tamf, amend_indicator: 'I', fe_tsmp: DateTime.parse('2005-01-01 00:00:00'), msrgp_code: 'EX', msr_type: 'EXF', tty_code: '611', adval1_rate: BigDecimal('22.000'), spfc1_rate: BigDecimal('108.6500')) }
    let!(:tamf3) { create(:tamf, amend_indicator: 'I', fe_tsmp: DateTime.parse('2007-10-01 00:00:00'), msrgp_code: 'EX', msr_type: 'EXL', tty_code: '520', spfc1_rate: BigDecimal('0.6007')) }
    let!(:tamf4) { create(:tamf, amend_indicator: 'I', fe_tsmp: DateTime.parse('2005-01-01 00:00:00'), msrgp_code: 'EX', msr_type: 'EXF', tty_code: '551') }

    let!(:mfcm1) { create(:mfcm, :with_goods_nomenclature, amend_indicator: 'I', fe_tsmp: DateTime.parse('2005-01-01 11:00:00'), msrgp_code: 'EX', msr_type: 'EXF', tty_code: '423', cmdty_code: '0101010100') }
    let!(:mfcm2) { create(:mfcm, :with_goods_nomenclature, amend_indicator: 'I', fe_tsmp: DateTime.parse('2006-06-01 00:00:00'), msrgp_code: 'EX', msr_type: 'EXF', tty_code: '611', cmdty_code: '0202020200') }
    let!(:mfcm3) { create(:mfcm, :with_goods_nomenclature, amend_indicator: 'I', fe_tsmp: DateTime.parse('2007-11-15 11:00:00'), msrgp_code: 'EX', msr_type: 'EXL', tty_code: '520', cmdty_code: '0303030300', le_tsmp: DateTime.parse('2007-12-01 00:00:00')) }
    let!(:mfcm4) { create(:mfcm, :with_goods_nomenclature, amend_indicator: 'I', fe_tsmp: DateTime.parse('2007-10-01 00:00:00'), msrgp_code: 'EX', msr_type: 'EXL', tty_code: '520', cmdty_code: '0404040400') }
    let!(:mfcm5) { create(:mfcm, :with_goods_nomenclature, amend_indicator: 'I', fe_tsmp: DateTime.parse('2005-01-01 00:00:00'), msrgp_code: 'EX', msr_type: 'EXF', tty_code: '551', cmdty_code: '0505050500') }

    let!(:geographical_area) { create :geographical_area, :twenty_years, :erga_omnes }

    before do
      ChiefTransformer.instance.invoke(:initial_load)
    end

    it 'creates measures for 0101010100' do
      m = Measure.where(goods_nomenclature_item_id: '0101010100', validity_start_date: DateTime.parse('2005-01-01 11:00:00')).first
      expect(m.goods_nomenclature_item_id).to eq '0101010100'
      expect(m.measure_components.first.duty_amount).to eq 1.7799
      expect(m.measure_components.first.monetary_unit_code).to eq 'GBP'
    end

    it 'creates measures for 0202020200' do
      m = Measure.where(goods_nomenclature_item_id: '0202020200', validity_start_date: DateTime.parse('2006-06-01 00:00:00')).first
      expect(m.goods_nomenclature_item_id).to eq '0202020200'
      expect(m.measure_components.second.duty_amount).to eq 108.650
      expect(m.measure_components.second.monetary_unit_code).to eq 'GBP'
      expect(m.measure_components.first.duty_amount).to eq 22.0
    end

    it 'creates measures for 0303030300' do
      m = Measure.where(goods_nomenclature_item_id: '0303030300', validity_start_date: DateTime.parse('2007-11-15 11:00:00')).first
      expect(m.goods_nomenclature_item_id).to eq '0303030300'
      expect(m.validity_end_date).to eq DateTime.parse('2007-12-01 00:00:00')
      expect(m.measure_components.first.duty_amount).to eq 0.6007
      expect(m.measure_components.first.monetary_unit_code).to eq 'GBP'
    end

    it 'creates measures for 0404040400' do
      m = Measure.where(goods_nomenclature_item_id: '0404040400', validity_start_date: DateTime.parse('2007-10-01 00:00:00')).first
      expect(m.goods_nomenclature_item_id).to eq '0404040400'
      expect(m.validity_end_date).to eq DateTime.parse('2007-12-31 23:50:00')
      expect(m.measure_components.first.duty_amount).to eq 0.6007
      expect(m.measure_components.first.monetary_unit_code).to eq 'GBP'
    end

#     it 'creates measures for 0505050500' do
#       m = Measure.where(goods_nomenclature_item_id: '0505050500', validity_start_date: DateTime.parse('2005-01-01 00:00:00')).first
#       expect(m.goods_nomenclature_item_id).to eq '0505050500'
#       expect(m.measure_components.first.duty_amount).to eq 0
#     end
  end

  context 'TAMF Initial Load Scenario 2: Excise measures different countries' do
    let!(:in) { create(:geographical_area, geographical_area_id: 'IN', geographical_area_sid: 154, validity_start_date: DateTime.parse('1975-07-18 00:00:00')) }
    let!(:us) { create(:geographical_area, geographical_area_id: 'US', geographical_area_sid: 103, validity_start_date: DateTime.parse('1975-07-18 00:00:00')) }
    let!(:cn) { create(:geographical_area, geographical_area_id: 'CN', geographical_area_sid: 439, validity_start_date: DateTime.parse('1975-07-18 00:00:00')) }

    let!(:tame1) { create(:tame, amend_indicator: 'I', fe_tsmp: DateTime.parse('2005-01-01 11:00:00'), msrgp_code: 'EX', msr_type: 'EXF', tty_code: '423') }

    let!(:tamf1) { create(:tamf, amend_indicator: 'I', fe_tsmp: DateTime.parse('2005-01-01 11:00:00'), msrgp_code: 'EX', msr_type: 'EXF', tty_code: '423', cntry_orig: 'US', spfc1_rate: BigDecimal('1.7799')) }
    let!(:tamf2) { create(:tamf, amend_indicator: 'I', fe_tsmp: DateTime.parse('2005-01-01 11:00:00'), msrgp_code: 'EX', msr_type: 'EXF', tty_code: '423', cntry_orig: 'CN', spfc1_rate: BigDecimal('2.3000')) }
    let!(:tamf3) { create(:tamf, amend_indicator: 'I', fe_tsmp: DateTime.parse('2005-01-01 11:00:00'), msrgp_code: 'EX', msr_type: 'EXF', tty_code: '423', cntry_orig: 'IN', spfc1_rate: BigDecimal('2.0000')) }

    let!(:mfcm1) { create(:mfcm, :with_goods_nomenclature, amend_indicator: 'I', fe_tsmp: DateTime.parse('2005-01-01 11:00:00'), msrgp_code: 'EX', msr_type: 'EXF', tty_code: '423', cmdty_code: '0101010100') }

    before { ChiefTransformer.instance.invoke(:initial_load) }

    # If there are several TAMF records with values in CNTRYORIG or CNGPCODE this will result in that a Taric measure is created for each country/country group.
    it 'creates measures for US' do
      m = Measure.where(goods_nomenclature_item_id: '0101010100',
                        geographical_area_id: 'US',
                        validity_start_date: DateTime.parse('2005-01-01 11:00:00')).take

      expect(m.geographical_area_sid).to eq 103
      expect(m.measure_components.first.duty_amount).to eq 1.7799
      expect(m.measure_components.first.monetary_unit_code).to eq 'GBP'
    end

    it 'creates measures for CN' do
      m = Measure.where(goods_nomenclature_item_id: '0101010100',
                        geographical_area_id: 'CN',
                        validity_start_date: DateTime.parse('2005-01-01 11:00:00')).take
      expect(m.geographical_area_sid).to eq 439
      expect(m.measure_components.first.duty_amount).to eq 2.300
      expect(m.measure_components.first.monetary_unit_code).to eq 'GBP'
    end

    it 'creates measures for IN' do
      m = Measure.where(goods_nomenclature_item_id: '0101010100',
                        geographical_area_id: 'IN',
                        validity_start_date: DateTime.parse('2005-01-01 11:00:00')).take
      expect(m.geographical_area_sid).to eq 154
      expect(m.measure_components.first.duty_amount).to eq 2.000
      expect(m.measure_components.first.monetary_unit_code).to eq 'GBP'
    end
  end

  context 'Daily Update TAME' do
    let!(:mfcm1) { create(:mfcm, :with_goods_nomenclature, amend_indicator: 'I', fe_tsmp: DateTime.parse('2007-11-15 11:00:00'), msrgp_code: 'VT', msr_type: 'S', tty_code: '813', cmdty_code: '0101010100') }
    let!(:mfcm2) { create(:mfcm, :with_goods_nomenclature, amend_indicator: 'I', fe_tsmp: DateTime.parse('2008-01-01 00:00:00'), msrgp_code: 'VT', msr_type: 'S', tty_code: '813', cmdty_code: '0202020200') }
    let!(:mfcm3) { create(:mfcm, :with_goods_nomenclature, amend_indicator: 'I', fe_tsmp: DateTime.parse('2008-04-30 14:00:00'), msrgp_code: 'VT', msr_type: 'S', tty_code: '813', cmdty_code: '0303030300') }

    let!(:tame) { create(:tame, amend_indicator: 'I', fe_tsmp: DateTime.parse('2007-11-15 11:00:00'), msrgp_code: 'VT', msr_type: 'S', tty_code: '813', adval_rate: 15.000) }

    let!(:geographical_area) { create :geographical_area, :fifteen_years, :erga_omnes }

    before do
      ChiefTransformer.instance.invoke(:initial_load)
    end

    it 'creates the 0101010100 measure' do
      m = Measure.where(goods_nomenclature_item_id: '0101010100', validity_start_date: DateTime.parse('2007-11-15 11:00:00')).take
      expect(m.measure_components.first.duty_amount).to eq 15
    end

    it 'creates the 0202020200 measure' do
      m = Measure.where(goods_nomenclature_item_id: '0202020200', validity_start_date: DateTime.parse('2008-01-01 00:00:00')).take
      expect(m.measure_components.first.duty_amount).to eq 15
    end

    it 'creates the 0303030300 measure' do
      m = Measure.where(goods_nomenclature_item_id: '0303030300', validity_start_date: DateTime.parse('2008-04-30 14:00:00')).take
      expect(m.measure_components.first.duty_amount).to eq 15
    end

    context 'TAME Daily Scenario 1: Changed VAT rate' do
      context 'Alt 1. Update and Insert' do
        let!(:tame1) do
          create(:tame, amend_indicator: 'U',
                        fe_tsmp: DateTime.parse('2007-11-15 11:00:00'),
                        msrgp_code: 'VT',
                        msr_type: 'S',
                        tty_code: '813',
                        adval_rate: 15.000,
                        le_tsmp: DateTime.parse('2008-04-01 00:00:00'),
                        audit_tsmp: Time.now.ago(2.minutes))
        end
        let!(:tame2) do
          create(:tame, amend_indicator: 'I',
                        fe_tsmp: DateTime.parse('2008-04-01 00:00:00'),
                        msrgp_code: 'VT',
                        msr_type: 'S',
                        tty_code: '813',
                        adval_rate: 17.000,
                        audit_tsmp: Time.now.ago(1.minute))
        end

        it_results_in 'VAT and Excise TAME Daily Scenario 1: Changed VAT rate outcome'
      end

      # In alternative 2 and alternative 3 the Taric measure -3 just updates the existing measure component (43005) with the new rate since its Taric measure start date is after the received FEDATE.
      context 'Alt 2. Update' do
        let!(:tame1) do
          create(:tame, amend_indicator: 'U',
                        fe_tsmp: DateTime.parse('2008-04-01 00:00:00'),
                        msrgp_code: 'VT',
                        msr_type: 'S',
                        tty_code: '813',
                        adval_rate: 17.000)
        end

        it_results_in 'VAT and Excise TAME Daily Scenario 1: Changed VAT rate outcome'
      end

      context 'Alt 3. Delete and Insert' do
        let!(:tame4) do
          create(:tame, amend_indicator: 'X',
                        fe_tsmp: DateTime.parse('2008-04-01 00:00:00'),
                        msrgp_code: 'VT',
                        msr_type: 'S',
                        tty_code: '813',
                        adval_rate: 15.000)
        end
        let!(:tame5) do
          create(:tame, amend_indicator: 'I',
                        fe_tsmp: DateTime.parse('2008-04-01 00:00:00'),
                        msrgp_code: 'VT',
                        msr_type: 'S',
                        tty_code: '813',
                        adval_rate: 17.000)
        end

        it_results_in 'VAT and Excise TAME Daily Scenario 1: Changed VAT rate outcome'
      end

      # New, changed and deleted national measures in Taric

      # From the above mentioned records the following national measures will exist after the CHIEF records have been handled, this is the case independent if the records are received as alternative 1 or alternative 2.
      # New records
      # Measure Sid Start Date  End Date  Commodity Duty Amount
      #   -1  2007-11-16  2008-03-31  0101010100  15%
      #   -2  2008-01-01  2008-03-31  0202020200  15%
      #   -3  2008-05-01    0303030300  17%
      # * -4  2008-04-01    0101010100  17%
      # * -5  2008-04-01    0202020200  17%
    end

    context 'TAME Daily Scenario 2: VAT applied to another commodity code' do
      context 'Alt 1. Update and Insert' do
        let!(:mfcm4) do
          create(:mfcm, amend_indicator: 'U',
                        fe_tsmp: DateTime.parse('2007-11-15 11:00:00'),
                        le_tsmp: DateTime.parse('2008-04-01 00:00:00'),
                        msrgp_code: 'VT',
                        msr_type: 'S',
                        tty_code: '813',
                        cmdty_code: '0101010100')
        end
        let!(:mfcm5) do
          create(:mfcm, :with_goods_nomenclature,
                 amend_indicator: 'I',
                 fe_tsmp: DateTime.parse('2008-04-01 00:00:00'),
                 msrgp_code: 'VT',
                 msr_type: 'S',
                 tty_code: '813',
                 cmdty_code: '0404040400')
        end

        it_results_in 'VAT and Excise TAME Daily Scenario 2: VAT applied to another commodity code outcome'
      end

      context 'Alt 2. Delete and Insert' do
        let!(:mfcm4) do
          create(:mfcm, amend_indicator: 'X',
                        fe_tsmp: DateTime.parse('2008-04-01 00:00:00'),
                        msrgp_code: 'VT',
                        msr_type: 'S',
                        tty_code: '813',
                        cmdty_code: '0101010100')
        end
        let!(:mfcm5) do
          create(:mfcm, :with_goods_nomenclature,
                 amend_indicator: 'I',
                 fe_tsmp: DateTime.parse('2008-04-01 00:00:00'),
                 msrgp_code: 'VT',
                 msr_type: 'S',
                 tty_code: '813',
                 cmdty_code: '0404040400')
        end

        it_results_in 'VAT and Excise TAME Daily Scenario 2: VAT applied to another commodity code outcome'
      end
    end

    context 'TAME Daily Scenario 3: VAT no longer applied to commodity' do
      context 'Alt 1. Update' do
        let!(:mfcm4) do
          create(:mfcm, amend_indicator: 'U',
                        fe_tsmp: DateTime.parse('2007-11-15 11:00:00'),
                        le_tsmp: DateTime.parse('2008-04-01 00:00:00'),
                        msrgp_code: 'VT',
                        msr_type: 'S',
                        tty_code: '813',
                        cmdty_code: '0101010100')
        end

        it_results_in 'VAT and Excise TAME Daily Scenario 3: VAT no longer applied to commodity outcome'
      end

      context 'Alt 2. Delete' do
        let!(:mfcm4) do
          create(:mfcm, amend_indicator: 'X',
                        fe_tsmp: DateTime.parse('2008-04-01 00:00:00'),
                        msrgp_code: 'VT',
                        msr_type: 'S',
                        tty_code: '813',
                        cmdty_code: '0101010100')
        end

        it_results_in 'VAT and Excise TAME Daily Scenario 3: VAT no longer applied to commodity outcome'
      end
    end

    context 'TAME Daily Scenario 4: VAT applied to additional commodity' do
      context 'Alt 1. Insert' do
        let!(:mfcm4) do
          create(:mfcm, :with_goods_nomenclature,
                 amend_indicator: 'I',
                 fe_tsmp: DateTime.parse('2008-01-01 00:00:00'),
                 msrgp_code: 'VT',
                 msr_type: 'S',
                 tty_code: '813',
                 cmdty_code: '0404040400')
        end

        it_results_in 'VAT and Excise TAME Daily Scenario 4: VAT applied to additional commodity outcome'
      end
    end

    context 'TAME Daily Scenario 5: VAT applied to incorrect commodity' do
      context 'Alt 1. Deletion' do
        let!(:mfcm4) do
          create(:mfcm, :with_goods_nomenclature,
                 amend_indicator: 'X',
                 fe_tsmp: DateTime.parse('2007-11-15 11:00:00'),
                 msrgp_code: 'VT',
                 msr_type: 'S',
                 tty_code: '813',
                 cmdty_code: '0101010100')
        end

        it_results_in 'VAT and Excise TAME Daily Scenario 5: VAT applied to incorrect commodity outcome'
      end
    end

    context 'TAME Daily Scenario 6: VAT removed' do
      context 'Alt 1. Update, Update and delete' do
        let!(:mfcm4) do
          create(:mfcm, amend_indicator: 'U',
                        fe_tsmp: DateTime.parse('2007-11-15 11:00:00'),
                        le_tsmp: DateTime.parse('2008-04-01 00:00:00'),
                        msrgp_code: 'VT',
                        msr_type: 'S',
                        tty_code: '813',
                        cmdty_code: '0101010100')
        end
        let!(:mfcm5) do
          create(:mfcm, :with_goods_nomenclature,
                 amend_indicator: 'U',
                 fe_tsmp: DateTime.parse('2008-01-01 00:00:00'),
                 le_tsmp: DateTime.parse('2008-04-01 00:00:00'),
                 msrgp_code: 'VT',
                 msr_type: 'S',
                 tty_code: '813',
                 cmdty_code: '0202020200')
        end
        let!(:mfcm6) do
          create(:mfcm, :with_goods_nomenclature,
                 amend_indicator: 'X',
                 fe_tsmp: DateTime.parse('2008-05-01 00:00:00'),
                 msrgp_code: 'VT',
                 msr_type: 'S',
                 tty_code: '813',
                 cmdty_code: '0303030300')
        end

        it_results_in 'VAT and Excise TAME Daily Scenario 6: VAT removed outcome'
      end

      context 'Alt 2. Single Update' do
        # Won't happen according to the documentation
      end

      context 'Alt 3. Single Deletetion' do
        # Won't happen according to the documentation
      end

      context 'Alt 4. Three Deletions' do
        let!(:mfcm4) do
          create(:mfcm, amend_indicator: 'X',
                        fe_tsmp: DateTime.parse('2008-04-01 00:00:00'),
                        msrgp_code: 'VT',
                        msr_type: 'S',
                        tty_code: '813',
                        cmdty_code: '0101010100')
        end
        let!(:mfcm5) do
          create(:mfcm, :with_goods_nomenclature,
                 amend_indicator: 'X',
                 fe_tsmp: DateTime.parse('2008-04-01 00:00:00'),
                 msrgp_code: 'VT',
                 msr_type: 'S',
                 tty_code: '813',
                 cmdty_code: '0202020200')
        end
        let!(:mfcm6) do
          create(:mfcm, :with_goods_nomenclature,
                 amend_indicator: 'X',
                 fe_tsmp: DateTime.parse('2008-05-01 00:00:00'),
                 msrgp_code: 'VT',
                 msr_type: 'S',
                 tty_code: '813',
                 cmdty_code: '0303030300')
        end

        it_results_in 'VAT and Excise TAME Daily Scenario 6: VAT removed outcome'
      end

      context 'Alt 5. One TAME deletion and Three MFCM Deletions' do
        let!(:tame2) do
          create(:tame, amend_indicator: 'X',
                        fe_tsmp: DateTime.parse('2008-04-01 00:00:00'),
                        msrgp_code: 'VT',
                        msr_type: 'S',
                        tty_code: '813',
                        adval_rate: 15.000)
        end
        let!(:mfcm4) do
          create(:mfcm, amend_indicator: 'X',
                        fe_tsmp: DateTime.parse('2008-04-01 00:00:00'),
                        msrgp_code: 'VT',
                        msr_type: 'S',
                        tty_code: '813',
                        cmdty_code: '0101010100')
        end
        let!(:mfcm5) do
          create(:mfcm, :with_goods_nomenclature,
                 amend_indicator: 'X',
                 fe_tsmp: DateTime.parse('2008-04-01 00:00:00'),
                 msrgp_code: 'VT',
                 msr_type: 'S',
                 tty_code: '813',
                 cmdty_code: '0202020200')
        end
        let!(:mfcm6) do
          create(:mfcm, :with_goods_nomenclature,
                 amend_indicator: 'X',
                 fe_tsmp: DateTime.parse('2008-05-01 00:00:00'),
                 msrgp_code: 'VT',
                 msr_type: 'S',
                 tty_code: '813',
                 cmdty_code: '0303030300')
        end

        it_results_in 'VAT and Excise TAME Daily Scenario 6: VAT removed outcome'
      end
    end

    context 'TAME Daily Scenario 7: Incorrect VAT rate' do
      context 'Alt 1. Update' do
        let!(:tame2) do
          create(:tame, amend_indicator: 'U',
                        fe_tsmp: DateTime.parse('2007-11-15 11:00:00'),
                        msrgp_code: 'VT',
                        msr_type: 'S',
                        tty_code: '813',
                        adval_rate: 17.00)
        end

        it_results_in 'VAT and Excise TAME Daily Scenario 7: Incorrect VAT rate outcome'
      end
    end
  end

  context 'Daily Update TAMF' do
    let!(:mfcm1) do
      create(:mfcm, :with_goods_nomenclature,
             amend_indicator: 'I',
             fe_tsmp: DateTime.parse('2007-11-15 11:00:00'),
             msrgp_code: 'EX',
             msr_type: 'EXF',
             tty_code: '411',
             cmdty_code: '0101010100')
    end
    let!(:mfcm2) do
      create(:mfcm, :with_goods_nomenclature,
             amend_indicator: 'I',
             fe_tsmp: DateTime.parse('2008-01-01 00:00:00'),
             msrgp_code: 'EX',
             msr_type: 'EXF',
             tty_code: '411',
             cmdty_code: '0202020200')
    end
    let!(:mfcm3) do
      create(:mfcm, :with_goods_nomenclature,
             amend_indicator: 'I',
             fe_tsmp: DateTime.parse('2008-04-30 14:00:00'),
             msrgp_code: 'EX',
             msr_type: 'EXF',
             tty_code: '411',
             cmdty_code: '0303030300')
    end
    let!(:mfcm4) do
      create(:mfcm, :with_goods_nomenclature,
             amend_indicator: 'I',
             fe_tsmp: DateTime.parse('2007-11-15 11:00:00'),
             msrgp_code: 'EX',
             msr_type: 'EXF',
             tty_code: '570',
             cmdty_code: '0101010100')
    end
    let!(:mfcm5) do
      create(:mfcm, :with_goods_nomenclature,
             amend_indicator: 'I',
             fe_tsmp: DateTime.parse('2008-01-01 00:00:00'),
             msrgp_code: 'EX',
             msr_type: 'EXF',
             tty_code: '570',
             cmdty_code: '0202020200')
    end
    let!(:mfcm6) do
      create(:mfcm, :with_goods_nomenclature,
             amend_indicator: 'I',
             fe_tsmp: DateTime.parse('2008-04-30 14:00:00'),
             msrgp_code: 'EX',
             msr_type: 'EXF',
             tty_code: '570',
             cmdty_code: '0303030300')
    end
    # NOTE: these two tames are not included in the example, we feel they should be
    let!(:tame1) do
      create(:tame, amend_indicator: 'I',
                    fe_tsmp: DateTime.parse('2007-11-15 11:00:00'),
                    msrgp_code: 'EX',
                    msr_type: 'EXF',
                    tty_code: '411')
    end
    let!(:tame2) do
      create(:tame, amend_indicator: 'I',
                    fe_tsmp: DateTime.parse('2007-11-15 11:00:00'),
                    msrgp_code: 'EX',
                    msr_type: 'EXF',
                    tty_code: '570')
    end
    let!(:tamf1) do
      create(:tamf, amend_indicator: 'I',
                    fe_tsmp: DateTime.parse('2007-11-15 11:00:00'),
                    msrgp_code: 'EX',
                    msr_type: 'EXF',
                    tty_code: '411',
                    spfc1_rate: 20.0,
                    spfc2_rate: 1)
    end
    let!(:tamf2) do
      create(:tamf, amend_indicator: 'I',
                    fe_tsmp: DateTime.parse('2007-11-15 11:00:00'),
                    msrgp_code: 'EX',
                    msr_type: 'EXF',
                    tty_code: '570',
                    spfc1_rate: 10.0)
    end

    let!(:geographical_area) { create :geographical_area, :fifteen_years, :erga_omnes }

    before do
      ChiefTransformer.instance.invoke(:initial_load)
    end

    it 'creates measure for 0101010100 with two measure components for duty amount of 20% and max 1kg' do
      m = Measure.where(goods_nomenclature_item_id: '0101010100',
                        validity_start_date: DateTime.parse('2007-11-15 11:00:00'),
                        measure_type_id: 'DAA').take
      expect(m.measure_components.first.duty_amount).to eq 20
      expect(m.measure_components.last.duty_amount).to eq 1
    end

    it 'creates measure for 0202020200 with two measure components for duty amount of 20% and max 1kg' do
      m = Measure.where(goods_nomenclature_item_id: '0202020200',
                        validity_start_date: DateTime.parse('2008-01-01 00:00:00'),
                        measure_type_id: 'DAA').take
      expect(m.measure_components.first.duty_amount).to eq 20
      expect(m.measure_components.last.duty_amount).to eq 1
    end

    it 'creates measure for 0303030300 with two measure components for duty amount of 20% and max 1kg' do
      m = Measure.where(goods_nomenclature_item_id: '0303030300',
                        validity_start_date: DateTime.parse('2008-04-30 14:00:00'),
                        measure_type_id: 'DAA').take
      expect(m.measure_components.first.duty_amount).to eq 20
      expect(m.measure_components.last.duty_amount).to eq 1
    end

    it 'create measure for 0101010100 with one measure component, duty amount of 10%' do
      m = Measure.where(goods_nomenclature_item_id: '0101010100',
                        validity_start_date: DateTime.parse('2007-11-15 11:00:00'),
                        measure_type_id: 'EGJ').take
      expect(m.measure_components.first.duty_amount).to eq 10
    end

    it 'create measure for 0202020200 with one measure component, duty amount of 10%' do
      m = Measure.where(goods_nomenclature_item_id: '0202020200',
                        validity_start_date: DateTime.parse('2008-01-01 00:00:00'),
                        measure_type_id: 'EGJ').take
      expect(m.measure_components.first.duty_amount).to eq 10
    end

    it 'create measure for 0303030300 with one measure component, duty amount of 10%' do
      m = Measure.where(goods_nomenclature_item_id: '0303030300',
                        validity_start_date: DateTime.parse('2008-04-30 14:00:00'),
                        measure_type_id: 'EGJ').take
      expect(m.measure_components.first.duty_amount).to eq 10
    end

    describe 'TAMF Daily Scenario 1: Added max amount' do
      describe 'Alt 1. Update and Insert' do
        let!(:tamf3) do
          create(:tamf, amend_indicator: 'U',
                        fe_tsmp: DateTime.parse('2007-11-15 11:00:00'),
                        msrgp_code: 'EX',
                        msr_type: 'EXF',
                        tty_code: '570',
                        spfc1_rate: 10.0)
        end
        let!(:tamf4) do
          create(:tamf, amend_indicator: 'I',
                        fe_tsmp: DateTime.parse('2008-04-01 00:00:00'),
                        msrgp_code: 'EX',
                        msr_type: 'EXF',
                        tty_code: '570',
                        spfc1_rate: 10.0,
                        spfc2_rate: 2)
        end
        let!(:tame3) do
          create(:tame, amend_indicator: 'U',
                        fe_tsmp: DateTime.parse('2007-11-15 11:00:00'),
                        le_tsmp: DateTime.parse('2008-04-01 00:00:00'),
                        msrgp_code: 'EX',
                        msr_type: 'EXF',
                        tty_code: '570')
        end
        let!(:tame4) do
          create(:tame, amend_indicator: 'I',
                        fe_tsmp: DateTime.parse('2008-04-01 00:00:00'),
                        msrgp_code: 'EX',
                        msr_type: 'EXF',
                        tty_code: '570')
        end

        it_results_in 'VAT and Excise TAMF Daily Scenario 1: Added max amount outcome'
      end

      describe 'Alt 2. Update' do
        let!(:tamf3) do
          create(:tamf, amend_indicator: 'U',
                        fe_tsmp: DateTime.parse('2008-04-01 00:00:00'),
                        msrgp_code: 'EX',
                        msr_type: 'EXF',
                        tty_code: '570',
                        spfc1_rate: 10.0,
                        spfc2_rate: 2)
        end
        let!(:tame3) do
          create(:tame, amend_indicator: 'U',
                        fe_tsmp: DateTime.parse('2008-04-01 00:00:00'),
                        msrgp_code: 'EX',
                        msr_type: 'EXF',
                        tty_code: '570')
        end

        it_results_in 'VAT and Excise TAMF Daily Scenario 1: Added max amount outcome'
      end

      describe 'Alt 3. Update' do
        let!(:tamf3) do
          create(:tamf, amend_indicator: 'X',
                        fe_tsmp: DateTime.parse('2008-04-01 00:00:00'),
                        msrgp_code: 'EX',
                        msr_type: 'EXF',
                        tty_code: '570',
                        spfc1_rate: 10.0)
        end
        let!(:tamf4) do
          create(:tamf, amend_indicator: 'I',
                        fe_tsmp: DateTime.parse('2008-04-01 00:00:00'),
                        msrgp_code: 'EX',
                        msr_type: 'EXF',
                        tty_code: '570',
                        spfc1_rate: 10.0,
                        spfc2_rate: 2)
        end
        let!(:tame3) do
          create(:tame, amend_indicator: 'X',
                        fe_tsmp: DateTime.parse('2008-04-01 00:00:00'),
                        msrgp_code: 'EX',
                        msr_type: 'EXF',
                        tty_code: '570')
        end
        let!(:tame4) do
          create(:tame, amend_indicator: 'I',
                        fe_tsmp: DateTime.parse('2008-04-01 00:00:00'),
                        msrgp_code: 'EX',
                        msr_type: 'EXF',
                        tty_code: '570')
        end

        it_results_in 'VAT and Excise TAMF Daily Scenario 1: Added max amount outcome'
      end
    end

    describe 'TAMF Daily Scenario 2: Missing max amount' do
      describe 'Alt 1. Update' do
        let!(:tame5) do
          create(:tame, amend_indicator: 'U',
                        fe_tsmp: DateTime.parse('2007-11-15 11:00:00'),
                        msrgp_code: 'EX',
                        msr_type: 'EXF',
                        tty_code: '570')
        end
        let!(:tamf3) do
          create(:tamf, amend_indicator: 'U',
                        fe_tsmp: DateTime.parse('2007-11-15 11:00:00'),
                        msrgp_code: 'EX',
                        msr_type: 'EXF',
                        tty_code: '570',
                        spfc1_rate: 10.0,
                        spfc2_rate: 2.0)
        end

        it_results_in 'VAT and Excise TAMF Daily Scenario 2: Missing max amount outcome'
      end
    end

    describe 'TAMF Daily Scenario 3: Removed max amount' do
      describe 'Alt 1. Update and Insert' do
        let!(:tamf3) do
          create(:tamf, amend_indicator: 'U',
                        fe_tsmp: DateTime.parse('2007-11-15 11:00:00'),
                        msrgp_code: 'EX',
                        msr_type: 'EXF',
                        tty_code: '411',
                        spfc1_rate: 20.0,
                        spfc2_rate: 1.0)
        end
        let!(:tamf4) do
          create(:tamf, amend_indicator: 'I',
                        fe_tsmp: DateTime.parse('2008-04-01 00:00:00'),
                        msrgp_code: 'EX',
                        msr_type: 'EXF',
                        tty_code: '411',
                        spfc1_rate: 20.0)
        end
        let!(:tame3) do
          create(:tame, amend_indicator: 'U',
                        fe_tsmp: DateTime.parse('2007-11-15 11:00:00'),
                        le_tsmp: DateTime.parse('2008-04-01 00:00:00'),
                        msrgp_code: 'EX',
                        msr_type: 'EXF',
                        tty_code: '411')
        end
        let!(:tame4) do
          create(:tame, amend_indicator: 'I',
                        fe_tsmp: DateTime.parse('2008-04-01 00:00:00'),
                        msrgp_code: 'EX',
                        msr_type: 'EXF',
                        tty_code: '411')
        end

        it_behaves_like 'VAT and Excise TAMF Daily Scenario 3: Removed max amount outcome'
      end

      describe 'Alt 2. Update' do
        let!(:tamf3) do
          create(:tamf, amend_indicator: 'U',
                        fe_tsmp: DateTime.parse('2008-04-01 00:00:00'),
                        msrgp_code: 'EX',
                        msr_type: 'EXF',
                        tty_code: '411',
                        spfc1_rate: 20.0)
        end
        let!(:tame3) do
          create(:tame, amend_indicator: 'U',
                        fe_tsmp: DateTime.parse('2008-04-01 00:00:00'),
                        msrgp_code: 'EX',
                        msr_type: 'EXF',
                        tty_code: '411')
        end

        it_behaves_like 'VAT and Excise TAMF Daily Scenario 3: Removed max amount outcome'
      end

      describe 'Alt 3. Delete and Insert' do
        let!(:tamf3) do
          create(:tamf, amend_indicator: 'X',
                        fe_tsmp: DateTime.parse('2008-04-01 00:00:00'),
                        msrgp_code: 'EX',
                        msr_type: 'EXF',
                        tty_code: '411',
                        spfc1_rate: 20.0,
                        spfc2_rate: 1)
        end
        let!(:tamf4) do
          create(:tamf, amend_indicator: 'I',
                        fe_tsmp: DateTime.parse('2008-04-01 00:00:00'),
                        msrgp_code: 'EX',
                        msr_type: 'EXF',
                        tty_code: '411',
                        spfc1_rate: 20.0)
        end
        let!(:tame3) do
          create(:tame, amend_indicator: 'X',
                        fe_tsmp: DateTime.parse('2008-04-01 00:00:00'),
                        msrgp_code: 'EX',
                        msr_type: 'EXF',
                        tty_code: '411')
        end
        let!(:tame4) do
          create(:tame, amend_indicator: 'I',
                        fe_tsmp: DateTime.parse('2008-04-01 00:00:00'),
                        msrgp_code: 'EX',
                        msr_type: 'EXF',
                        tty_code: '411')
        end

        it_behaves_like 'VAT and Excise TAMF Daily Scenario 3: Removed max amount outcome'
      end
    end
  end

  context 'Daily Update MFCM' do
    let!(:mfcm1) do
      create(:mfcm, :with_goods_nomenclature,
             amend_indicator: 'I',
             fe_tsmp: DateTime.parse('2007-11-15 11:00:00'),
             msrgp_code: 'VT',
             msr_type: 'S',
             tty_code: '813',
             cmdty_code: '0101010100')
    end

    let!(:tame) do
      create(:tame, amend_indicator: 'I',
                    fe_tsmp: DateTime.parse('2007-11-15 11:00:00'),
                    msrgp_code: 'VT',
                    msr_type: 'S',
                    tty_code: '813',
                    adval_rate: 15.000)
    end

    let!(:geographical_area) { create :geographical_area, :fifteen_years, :erga_omnes }

    before do
      ChiefTransformer.instance.invoke(:initial_load)
    end

    it 'creates the 0101010100 measure' do
      m = Measure.where(goods_nomenclature_item_id: '0101010100',
                        validity_start_date: DateTime.parse('2007-11-15 11:00:00')).take
      expect(m.measure_components.first.duty_amount).to eq 15
    end

    describe 'MFCM Daily Scenario 1: Updated measure with later start date' do
      describe 'Alt 1. Update' do
        let!(:mfcm2) do
          create(:mfcm, amend_indicator: 'U',
                        fe_tsmp: DateTime.parse('2008-01-01 00:00:00'),
                        msrgp_code: 'VT',
                        msr_type: 'S',
                        tty_code: '813',
                        cmdty_code: '0101010100')
        end

        it_behaves_like 'VAT and Excise MFCM Daily Scenario 1: Updated measure with later start date outcome'
      end
    end

    describe 'MFCM Daily Scenario 2: Updated measure with later start date' do
      describe 'Alt 1: Update and Insert' do
        let!(:mfcm2) do
          create(:mfcm, amend_indicator: 'U',
                        fe_tsmp: DateTime.parse('2007-11-15 11:00:00'),
                        le_tsmp: DateTime.parse('2007-12-31 11:00:00'),
                        msrgp_code: 'VT',
                        msr_type: 'S',
                        tty_code: '813',
                        cmdty_code: '0101010100')
        end
        let!(:mfcm3) do
          create(:mfcm, amend_indicator: 'I',
                        fe_tsmp: DateTime.parse('2008-01-01 00:00:00'),
                        msrgp_code: 'VT',
                        msr_type: 'S',
                        tty_code: '813',
                        cmdty_code: '0101010100')
        end

        it_behaves_like 'VAT and Excise MFCM Daily Scenario 2: Updated measure with later start date outcome'
      end
    end

    describe 'MFCM Daily Scenario 3: Updated measure with later start date for terminated measure' do
      describe 'Alt 1: Update' do
        let!(:mfcm1) do
          create(:mfcm, :with_goods_nomenclature,
                 amend_indicator: 'I',
                 fe_tsmp: DateTime.parse('2007-11-15 11:00:00'),
                 le_tsmp: DateTime.parse('2007-11-30 00:00:00'),
                 msrgp_code: 'VT',
                 msr_type: 'S',
                 tty_code: '813',
                 cmdty_code: '0101010100')
        end
        let!(:mfcm2) do
          create(:mfcm, amend_indicator: 'U',
                        fe_tsmp: DateTime.parse('2008-01-01 00:00:00'),
                        msrgp_code: 'VT',
                        msr_type: 'S',
                        tty_code: '813',
                        cmdty_code: '0101010100')
        end

        it_results_in 'VAT and Excise MFCM Daily Scenario 3: Updated measure with later start date for terminated measure outcome'
      end

      describe 'Alt 2: Insert' do
        let!(:mfcm1) do
          create(:mfcm, :with_goods_nomenclature,
                 amend_indicator: 'I',
                 fe_tsmp: DateTime.parse('2007-11-15 11:00:00'),
                 le_tsmp: DateTime.parse('2007-11-30 00:00:00'),
                 msrgp_code: 'VT',
                 msr_type: 'S',
                 tty_code: '813',
                 cmdty_code: '0101010100')
        end
        let!(:mfcm2) do
          create(:mfcm, amend_indicator: 'I',
                        fe_tsmp: DateTime.parse('2008-01-01 00:00:00'),
                        msrgp_code: 'VT',
                        msr_type: 'S',
                        tty_code: '813',
                        cmdty_code: '0101010100')
        end

        it_results_in 'VAT and Excise MFCM Daily Scenario 3: Updated measure with later start date for terminated measure outcome'
      end
    end

    describe 'MFCM Daily Scenario 4: Start date for measure moved forward' do
      describe 'Alt 1: Deletion and Insertion' do
        let!(:mfcm2) do
          create(:mfcm, amend_indicator: 'X',
                        fe_tsmp: DateTime.parse('2007-11-15 11:00:00'),
                        msrgp_code: 'VT',
                        msr_type: 'S',
                        tty_code: '813',
                        cmdty_code: '0101010100')
        end
        let!(:mfcm3) do
          create(:mfcm, amend_indicator: 'I',
                        fe_tsmp: DateTime.parse('2008-01-01 00:00:00'),
                        msrgp_code: 'VT',
                        msr_type: 'S',
                        tty_code: '813',
                        cmdty_code: '0101010100')
        end

        it_results_in 'VAT and Excise MFCM Daily Scenario 4: Start date for measure moved forward outcome'
      end
    end
  end

  context 'Unsupported Scenario 1: Several updates in same daily update file' do
    let!(:mfcm1) do
      create(:mfcm, :with_goods_nomenclature,
             amend_indicator: 'I',
             fe_tsmp: DateTime.parse('2008-01-01 00:00:00'),
             msrgp_code: 'EX',
             msr_type: 'EXF',
             tty_code: '411',
             cmdty_code: '0101010100')
    end
    let!(:tame1) do
      create(:tame, amend_indicator: 'I',
                    fe_tsmp: DateTime.parse('2008-01-01 00:00:00'),
                    msrgp_code: 'EX',
                    msr_type: 'EXF',
                    tty_code: '411')
    end
    let!(:tamf1) do
      create(:tamf, amend_indicator: 'I',
                    fe_tsmp: DateTime.parse('2008-01-01 00:00:00'),
                    msrgp_code: 'EX',
                    msr_type: 'EXF',
                    tty_code: '411',
                    adval1_rate: 20.0)
    end

    let!(:geographical_area) { create :geographical_area, :fifteen_years, :erga_omnes }

    before { ChiefTransformer.instance.invoke(:initial_load) }

    it 'creates one measure' do
      expect(Measure.count).to eq 1
    end

    it 'measure for 0101010100 with duty rate of 20.0' do
      m = Measure.where(goods_nomenclature_item_id: '0101010100',
                        validity_start_date: DateTime.parse('2008-01-01 00:00:00')).take
      expect(m.measure_components.first.duty_amount).to eq 20
    end

    describe 'Alt 1. Multiple updates' do
      let!(:tame2) do
        create(:tame, amend_indicator: 'U',
                      fe_tsmp: DateTime.parse('2008-02-01 00:00:00'),
                      audit_tsmp: Time.now.ago(1.minute),
                      msrgp_code: 'EX',
                      msr_type: 'EXF',
                      tty_code: '411')
      end
      let!(:tame3) do
        create(:tame, amend_indicator: 'U',
                      fe_tsmp: DateTime.parse('2008-04-01 00:00:00'),
                      msrgp_code: 'EX',
                      msr_type: 'EXF',
                      tty_code: '411')
      end
      let!(:tamf2) do
        create(:tamf, amend_indicator: 'U',
                      fe_tsmp: DateTime.parse('2008-02-01 00:00:00'),
                      msrgp_code: 'EX',
                      msr_type: 'EXF',
                      tty_code: '411',
                      adval1_rate: 19.0)
      end
      let!(:tamf3) do
        create(:tamf, amend_indicator: 'U',
                      fe_tsmp: DateTime.parse('2008-04-01 00:00:00'),
                      msrgp_code: 'EX',
                      msr_type: 'EXF',
                      tty_code: '411',
                      adval1_rate: 18.0)
      end

      it_results_in 'Unsupported Scenario 1: Several updates in same daily update file outcome'
    end
  end

  context 'Unsupported Scenario 2: Insert and delete in same daily update file' do
    let!(:tame1) do
      create(:tame, amend_indicator: 'I',
                    fe_tsmp: DateTime.parse('2007-01-01 00:00:00'),
                    msrgp_code: 'EX',
                    msr_type: 'EXF',
                    tty_code: '411')
    end
    let!(:tamf1) do
      create(:tamf, amend_indicator: 'I',
                    fe_tsmp: DateTime.parse('2007-01-01 00:00:00'),
                    msrgp_code: 'EX',
                    msr_type: 'EXF',
                    tty_code: '411',
                    adval1_rate: 20.0)
    end

    let!(:geographical_area) { create :geographical_area, :fifteen_years, :erga_omnes }

    before { ChiefTransformer.instance.invoke(:initial_load) }

    it 'no Taric measures should be created' do
      expect(Measure.count).to eq 0
    end

    context 'Alt 1. Insertion and deletion' do
      let!(:mfcm1) do
        create(:mfcm, amend_indicator: 'I',
                      fe_tsmp: DateTime.parse('2008-01-01 00:00:00'),
                      msrgp_code: 'EX',
                      msr_type: 'EXF',
                      tty_code: '411',
                      cmdty_code: '0101010100')
      end
      let!(:mfcm2) do
        create(:mfcm, amend_indicator: 'X',
                      fe_tsmp: DateTime.parse('2008-01-01 00:00:00'),
                      msrgp_code: 'EX',
                      msr_type: 'EXF',
                      tty_code: '411',
                      cmdty_code: '0101010100')
      end

      it_results_in 'Unsupported Scenario 2: Insert and delete in same daily update file outcome'
    end
  end

  context 'Unsupported Scenario 3: Insert and update in same daily file' do
    describe 'Alt 1. Insert and Update' do
      let!(:mfcm1) do
        create(:mfcm, :with_goods_nomenclature,
               amend_indicator: 'I',
               fe_tsmp: DateTime.parse('2008-03-01 00:00:00'),
               audit_tsmp: Time.now.ago(2.minutes),
               msrgp_code: 'EX',
               msr_type: 'EXF',
               tty_code: '411',
               cmdty_code: '0101010100')
      end
      let!(:tame1) do
        create(:tame, amend_indicator: 'I',
                      fe_tsmp: DateTime.parse('2008-03-01 00:00:00'),
                      msrgp_code: 'EX',
                      audit_tsmp: Time.now.ago(1.minute),
                      msr_type: 'EXF',
                      tty_code: '411')
      end
      let!(:tame2) do
        create(:tame, amend_indicator: 'U',
                      fe_tsmp: DateTime.parse('2008-03-01 00:00:00'),
                      msrgp_code: 'EX',
                      msr_type: 'EXF',
                      tty_code: '411')
      end
      let!(:tamf1) do
        create(:tamf, amend_indicator: 'I',
                      fe_tsmp: DateTime.parse('2008-03-01 00:00:00'),
                      msrgp_code: 'EX',
                      msr_type: 'EXF',
                      tty_code: '411',
                      adval1_rate: 20.0)
      end
      let!(:tamf2) do
        create(:tamf, amend_indicator: 'U',
                      fe_tsmp: DateTime.parse('2008-03-01 00:00:00'),
                      msrgp_code: 'EX',
                      msr_type: 'EXF',
                      tty_code: '411',
                      adval1_rate: 15.0)
      end

      let!(:geographical_area) { create :geographical_area, :fifteen_years, :erga_omnes }

      it_results_in 'Unsupported Scenario 3: Insert and update in same daily file outcome'
    end

    describe 'Alt 2. Insert' do
      let!(:mfcm1) do
        create(:mfcm, :with_goods_nomenclature,
               amend_indicator: 'I',
               fe_tsmp: DateTime.parse('2008-03-01 00:00:00'),
               msrgp_code: 'EX',
               msr_type: 'EXF',
               tty_code: '411',
               cmdty_code: '0101010100')
      end
      let!(:tame1) do
        create(:tame, amend_indicator: 'I',
                      fe_tsmp: DateTime.parse('2008-03-01 00:00:00'),
                      msrgp_code: 'EX',
                      msr_type: 'EXF',
                      tty_code: '411')
      end
      let!(:tamf2) do
        create(:tamf, amend_indicator: 'I',
                      fe_tsmp: DateTime.parse('2008-03-01 00:00:00'),
                      msrgp_code: 'EX',
                      msr_type: 'EXF',
                      tty_code: '411',
                      adval1_rate: 15.0)
      end

      let!(:geographical_area) { create :geographical_area, :fifteen_years, :erga_omnes }

      it_results_in 'Unsupported Scenario 3: Insert and update in same daily file outcome'
    end
  end
end
