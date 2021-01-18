require 'rails_helper'
require 'chief_transformer'

describe "CHIEF: Prohibitions and Restrictions \n" do
  before(:all) do
    preload_standing_data
  end

  before do
    create :base_regulation, base_regulation_id: 'IYY99990',
                             validity_start_date: Date.new(1971, 12, 31)
  end

  after(:all) { clear_standing_data }

  # Create Measure types used in transformations, so that validations would pass.
  # Faster than loading static_national_data.sql
  let!(:measure_type_qrc) { create :measure_type, measure_type_id: 'QRC', validity_start_date: Date.new(1972, 1, 1) }
  let!(:measure_type_att) { create :measure_type, measure_type_id: 'ATT', validity_start_date: Date.new(1972, 1, 1) }
  let!(:measure_type_cvd) { create :measure_type, measure_type_id: 'CVD', validity_start_date: Date.new(1972, 1, 1) }
  let!(:measure_type_coe) { create :measure_type, measure_type_id: 'COE', validity_start_date: Date.new(1972, 1, 1) }

  describe "Initial Load Scenario P&R \n" do
    # In this scenario a number of P&R measures are created. The created measures represent Export and Import restrictions for:
    # * specific countries or regions (IQ, XC)
    # * a country group that is translated to an EU country group (D066)
    # * a national country group that has been created in the TARIC database (A001)

    let!(:a001) { create(:geographical_area, geographical_area_id: 'A001', geographical_area_sid: -1, validity_start_date: DateTime.parse('1975-07-18 00:00:00')) }
    let!(:iq) { create(:geographical_area, geographical_area_id: 'IQ', geographical_area_sid: -2, validity_start_date: DateTime.parse('1975-07-18 00:00:00')) }
    let!(:xc) { create(:geographical_area, geographical_area_id: 'XC', geographical_area_sid: -3, validity_start_date: DateTime.parse('1975-07-18 00:00:00')) }

    # excluded countries for D066 AD,FO,NO,SM,IS
    let!(:ad) { create(:geographical_area, geographical_area_id: 'AD', geographical_area_sid: 140, validity_start_date: DateTime.parse('1975-07-18 00:00:00')) }
    let!(:fo) { create(:geographical_area, geographical_area_id: 'FO', geographical_area_sid: 330, validity_start_date: DateTime.parse('1975-07-18 00:00:00')) }
    let!(:no) { create(:geographical_area, geographical_area_id: 'NO', geographical_area_sid: 252, validity_start_date: DateTime.parse('1975-07-18 00:00:00')) }
    let!(:sm) { create(:geographical_area, geographical_area_id: 'SM', geographical_area_sid: 382, validity_start_date: DateTime.parse('1975-07-18 00:00:00')) }
    let!(:is) { create(:geographical_area, geographical_area_id: 'IS', geographical_area_sid: 53, validity_start_date: DateTime.parse('1975-07-18 00:00:00')) }

    let!(:tame1) { create(:tame, :prohibition, amend_indicator: 'I', fe_tsmp: DateTime.parse('2006-07-24 08:45:00'), msrgp_code: 'HO', msr_type: 'CON', tar_msr_no: '12113000') }
    let!(:tame2) { create(:tame, :prohibition, amend_indicator: 'I', fe_tsmp: DateTime.parse('2008-04-01 00:00:00'), msrgp_code: 'PR', msr_type: 'ATT', tar_msr_no: '1210100010') }
    let!(:tame3) { create(:tame, :prohibition, amend_indicator: 'I', fe_tsmp: DateTime.parse('2008-04-01 00:00:00'), msrgp_code: 'PR', msr_type: 'CVD', tar_msr_no: '2106909829') }
    let!(:tame4) { create(:tame, :prohibition, amend_indicator: 'I', fe_tsmp: DateTime.parse('2008-04-01 00:00:00'), msrgp_code: 'PR', msr_type: 'QRC', tar_msr_no: '97060000') }

    let!(:tamf1) { create(:tamf, :prohibition, amend_indicator: 'I', fe_tsmp: DateTime.parse('2006-07-24 08:45:00'), msrgp_code: 'HO', msr_type: 'CON', tar_msr_no: '12113000', cntry_orig: 'IQ') }
    let!(:tamf2) { create(:tamf, :prohibition, amend_indicator: 'I', fe_tsmp: DateTime.parse('2008-04-01 00:00:00'), msrgp_code: 'PR', msr_type: 'ATT', tar_msr_no: '1210100010', cntry_disp: 'XC') }
    let!(:tamf3) { create(:tamf, :prohibition, amend_indicator: 'I', fe_tsmp: DateTime.parse('2008-04-01 00:00:00'), msrgp_code: 'PR', msr_type: 'CVD', tar_msr_no: '2106909829', cngp_code: 'D066') }
    let!(:tamf4) { create(:tamf, :prohibition, amend_indicator: 'I', fe_tsmp: DateTime.parse('2008-04-01 00:00:00'), msrgp_code: 'PR', msr_type: 'QRC', tar_msr_no: '97060000', cngp_code: 'A001') }

    let!(:mfcm1) { create(:mfcm, :with_goods_nomenclature, :prohibition, amend_indicator: 'I', fe_tsmp: DateTime.parse('2006-07-24 08:45:00'), msrgp_code: 'HO', msr_type: 'CON', tar_msr_no: '12113000', cmdty_code: '1211300000') }
    let!(:mfcm2) { create(:mfcm, :with_goods_nomenclature, :prohibition, amend_indicator: 'I', fe_tsmp: DateTime.parse('2007-10-01 00:00:00'), msrgp_code: 'PR', msr_type: 'ATT', tar_msr_no: '1210100010', cmdty_code: '1210100010') }
    let!(:mfcm3) { create(:mfcm, :with_goods_nomenclature, :prohibition, amend_indicator: 'I', fe_tsmp: DateTime.parse('2008-04-01 00:00:00'), msrgp_code: 'PR', msr_type: 'CVD', tar_msr_no: '2106909829', cmdty_code: '2106909829') }
    let!(:mfcm4) { create(:mfcm, :with_goods_nomenclature, :prohibition, amend_indicator: 'I', fe_tsmp: DateTime.parse('2008-04-01 00:00:00'), msrgp_code: 'PR', msr_type: 'QRC', tar_msr_no: '97060000', cmdty_code: '9706000000') }
    let!(:mfcm5) { create(:mfcm, :with_goods_nomenclature, :prohibition, amend_indicator: 'I', fe_tsmp: DateTime.parse('2008-04-01 00:00:00'), msrgp_code: 'PR', msr_type: 'QRC', tar_msr_no: '97060000', cmdty_code: '9706000010') }
    let!(:mfcm6) { create(:mfcm, :with_goods_nomenclature, :prohibition, amend_indicator: 'I', fe_tsmp: DateTime.parse('2008-04-01 00:00:00'), msrgp_code: 'PR', msr_type: 'QRC', tar_msr_no: '97060000', cmdty_code: '9706000090') }

    let!(:geographical_area) { create :geographical_area, :fifteen_years, :erga_omnes, geographical_area_sid: 400 }

    before do
      ChiefTransformer.instance.invoke(:initial_load)
    end

    it 'creates 6 measures' do
      expect(Measure.count).to eq 6
    end

    it 'creates measure for 1211300000' do
      m = Measure.where(goods_nomenclature_item_id: '1211300000', validity_start_date: DateTime.parse('2006-07-24 08:45:00')).first
      expect(m).not_to be_nil
      expect(m[:geographical_area_id]).to eq 'IQ'
    end

    it 'creates measure for 1210100010' do
      m = Measure.where(goods_nomenclature_item_id: '1210100010', validity_start_date: DateTime.parse('2008-04-01 00:00:00')).first
      expect(m).not_to be_nil
      expect(m[:geographical_area_id]).to eq 'XC'
    end

    it 'creates measure for 2106909829' do
      m = Measure.where(goods_nomenclature_item_id: '2106909829', validity_start_date: DateTime.parse('2008-04-01 00:00:00')).first
      expect(m).not_to be_nil
      expect(m[:geographical_area_id]).to eq '1011'
    end

    it 'creates measure for 9706000000' do
      m = Measure.where(goods_nomenclature_item_id: '9706000000', validity_start_date: DateTime.parse('2008-04-01 00:00:00')).first
      expect(m).not_to be_nil
      expect(m[:geographical_area_id]).to eq 'A001'
    end

    it 'creates measure for 9706000010' do
      m = Measure.where(goods_nomenclature_item_id: '9706000010', validity_start_date: DateTime.parse('2008-04-01 00:00:00')).first
      expect(m).not_to be_nil
      expect(m[:geographical_area_id]).to eq 'A001'
    end

    it 'creates measure for 9706000090' do
      m = Measure.where(goods_nomenclature_item_id: '9706000090', validity_start_date: DateTime.parse('2008-04-01 00:00:00')).first
      expect(m).not_to be_nil
      expect(m[:geographical_area_id]).to eq 'A001'
    end

    it 'creates measure conditions for 1211300000' do
      m = Measure.where(goods_nomenclature_item_id: '1211300000').take
      expect(m.measure_conditions.count).to eq 3
      m = m.measure_conditions.first
      expect(m.condition_code).to eq 'Z'
      expect(m.certificate_code).to eq '113'
    end

    it 'creates measure conditions for 1210100010' do
      m = Measure.where(goods_nomenclature_item_id: '1210100010').take
      expect(m.measure_conditions.count).to eq 3
      m = m.measure_conditions.first
      expect(m.condition_code).to eq 'Z'
      expect(m.certificate_code).to eq '001'
    end

    it 'creates measure conditions for 2106909829' do
      m = Measure.where(goods_nomenclature_item_id: '2106909829').take
      expect(m.measure_conditions.count).to eq 2
      m = m.measure_conditions.first
      expect(m.condition_code).to eq 'B'
      expect(m.certificate_code).to eq '853'
    end

    it 'creates measure conditions for 9706000000' do
      m = Measure.where(goods_nomenclature_item_id: '9706000000').take
      expect(m.measure_conditions.count).to eq 2
      m = m.measure_conditions.first
      expect(m.condition_code).to eq 'B'
      expect(m.certificate_code).to eq '115'
    end

    it 'creates measure conditions for 9706000010' do
      m = Measure.where(goods_nomenclature_item_id: '9706000010').take
      expect(m.measure_conditions.count).to eq 2
      m = m.measure_conditions.first
      expect(m.condition_code).to eq 'B'
      expect(m.certificate_code).to eq '115'
    end

    it 'creates measure conditions for 9706000090' do
      m = Measure.where(goods_nomenclature_item_id: '9706000090').take
      expect(m.measure_conditions.count).to eq 2
      m = m.measure_conditions.first
      expect(m.condition_code).to eq 'B'
      expect(m.certificate_code).to eq '115'
    end

    it 'creates the following excluded countries or regions' do
      expect(MeasureExcludedGeographicalArea.all.count).to eq 5
    end

    it 'creates the following footnote association for 015' do
      f = FootnoteAssociationMeasure.where(measure_sid: -6, footnote_type_id: '04', footnote_id: '015').first
      expect(f).not_to be_nil
      expect(f.national).to be_truthy
    end

    it 'creates the following footnote association for 004' do
      f = FootnoteAssociationMeasure.where(measure_sid: -5, footnote_type_id: '04', footnote_id: '004').first
      expect(f).not_to be_nil
      expect(f.national).to be_truthy
    end

    it 'creates the following footnote association for 006' do
      f = FootnoteAssociationMeasure.where(measure_sid: -4, footnote_type_id: '04', footnote_id: '006').first
      expect(f).not_to be_nil
      expect(f.national).to be_truthy
    end

    it 'creates the following footnote association for 011' do
      f = FootnoteAssociationMeasure.where(measure_sid: -1, footnote_type_id: '04', footnote_id: '011').first
      expect(f).not_to be_nil
      expect(f.national).to be_truthy
    end

    it 'creates the following footnote association for 011#2' do
      f = FootnoteAssociationMeasure.where(measure_sid: -2, footnote_type_id: '04', footnote_id: '011').first
      expect(f).not_to be_nil
      expect(f.national).to be_truthy
    end

    it 'creates the following footnote association for 011#3' do
      f = FootnoteAssociationMeasure.where(measure_sid: -3, footnote_type_id: '04', footnote_id: '011').first
      expect(f).not_to be_nil
      expect(f.national).to be_truthy
    end

    describe "Daily Update TAME and TAMF \n" do
      # In this scenario the country group is changed from D066 to G012, which means that excluded countries will be removed for this measure.
      describe "Daily Scenario 1: Changed country group for measure \n" do
        context 'Alternative 1: Update & Insert' do
          let!(:tame5) do
            create(:tame, :prohibition,
                   amend_indicator: 'U',
                   fe_tsmp: DateTime.parse('2008-04-01 00:00:00'),
                   le_tsmp: DateTime.parse('2008-05-01 00:00:00'),
                   msrgp_code: 'PR',
                   msr_type: 'CVD',
                   tar_msr_no: '2106909829')
          end

          let!(:tame6) do
            create(:tame, :prohibition,
                   amend_indicator: 'I',
                   fe_tsmp: DateTime.parse('2008-05-01 00:00:00'),
                   msrgp_code: 'PR',
                   msr_type: 'CVD',
                   tar_msr_no: '2106909829')
          end

          let!(:tamf5) do
            create(:tamf, :prohibition,
                   amend_indicator: 'U',
                   fe_tsmp: DateTime.parse('2008-04-01 00:00:00'),
                   msrgp_code: 'PR',
                   msr_type: 'CVD',
                   cngp_code: 'D066',
                   tar_msr_no: '2106909829')
          end

          let!(:tamf6) do
            create(:tamf, :prohibition,
                   amend_indicator: 'I',
                   fe_tsmp: DateTime.parse('2008-05-01 00:00:00'),
                   msrgp_code: 'PR',
                   msr_type: 'CVD',
                   cngp_code: 'G012',
                   tar_msr_no: '2106909829')
          end

          it_results_in 'P&R Daily Update TAME and TAMF Daily Scenario 1: Changed country group for measure outcome'
        end

        context 'Alternative 2: Update' do
          let!(:tame5) do
            create(:tame, :prohibition,
                   amend_indicator: 'U',
                   fe_tsmp: DateTime.parse('2008-05-01 00:00:00'),
                   msrgp_code: 'PR',
                   msr_type: 'CVD',
                   tar_msr_no: '2106909829')
          end

          let!(:tamf5) do
            create(:tamf, :prohibition,
                   amend_indicator: 'U',
                   fe_tsmp: DateTime.parse('2008-05-01 00:00:00'),
                   msrgp_code: 'PR',
                   msr_type: 'CVD',
                   cngp_code: 'G012',
                   tar_msr_no: '2106909829')
          end

          it_results_in 'P&R Daily Update TAME and TAMF Daily Scenario 1: Changed country group for measure outcome'
        end

        context 'Alternative 3: Delete & Insert' do
          # NOTE: is example wrong, fe_tsmp was adjusted
          let!(:tame5) do
            create(:tame, :prohibition,
                   amend_indicator: 'X',
                   fe_tsmp: DateTime.parse('2008-05-01 00:00:00'),
                   msrgp_code: 'PR',
                   msr_type: 'CVD',
                   tar_msr_no: '2106909829')
          end

          let!(:tame6) do
            create(:tame, :prohibition,
                   amend_indicator: 'I',
                   fe_tsmp: DateTime.parse('2008-05-01 00:00:00'),
                   msrgp_code: 'PR',
                   msr_type: 'CVD',
                   tar_msr_no: '2106909829')
          end

          let!(:tamf5) do
            create(:tamf, :prohibition,
                   amend_indicator: 'X',
                   fe_tsmp: DateTime.parse('2008-05-01 00:00:00'),
                   msrgp_code: 'PR',
                   msr_type: 'CVD',
                   cngp_code: 'D066',
                   tar_msr_no: '2106909829')
          end

          # NOTE: is example wrong, fe_tsmp was adjusted
          let!(:tamf6) do
            create(:tamf, :prohibition,
                   amend_indicator: 'I',
                   fe_tsmp: DateTime.parse('2008-05-01 00:00:00'),
                   msrgp_code: 'PR',
                   msr_type: 'CVD',
                   cngp_code: 'G012',
                   tar_msr_no: '2106909829')
          end

          it_results_in 'P&R Daily Update TAME and TAMF Daily Scenario 1: Changed country group for measure outcome'
        end
      end

      describe "Daily Scenario 2: Restriction removed\n" do
        context 'Alternative 1: Update TAME & TAMF' do
          let!(:tame5) do
            create(:tame, :prohibition,
                   amend_indicator: 'U',
                   fe_tsmp: DateTime.parse('2008-04-01 00:00:00'),
                   le_tsmp: DateTime.parse('2008-05-31 17:50:00'),
                   msrgp_code: 'PR',
                   msr_type: 'QRC',
                   tar_msr_no: '97060000')
          end

          let!(:tamf5) do
            create(:tamf, :prohibition,
                   amend_indicator: 'U',
                   fe_tsmp: DateTime.parse('2008-04-01 00:00:00'),
                   msrgp_code: 'PR',
                   msr_type: 'QRC',
                   cngp_code: 'A001',
                   tar_msr_no: '97060000')
          end

          it_results_in 'P&R Daily Update TAME and TAMF Daily Scenario 2: Restriction removed outcome'
        end

        context 'Alternative 2: Delete TAME & TAMF' do
          let!(:tame5) do
            create(:tame, :prohibition,
                   amend_indicator: 'X',
                   fe_tsmp: DateTime.parse('2008-05-31 17:50:00'),
                   msrgp_code: 'PR',
                   msr_type: 'QRC',
                   tar_msr_no: '97060000')
          end

          let!(:tamf5) do
            create(:tamf, :prohibition,
                   amend_indicator: 'X',
                   fe_tsmp: DateTime.parse('2008-05-31 17:50:00'),
                   msrgp_code: 'PR',
                   msr_type: 'QRC',
                   cngp_code: 'A001',
                   tar_msr_no: '97060000')
          end

          it_results_in 'P&R Daily Update TAME and TAMF Daily Scenario 2: Restriction removed outcome'
        end

        context 'Alternative 3: Delete TAME' do
          let!(:tame5) do
            create(:tame, :prohibition,
                   amend_indicator: 'X',
                   fe_tsmp: DateTime.parse('2008-05-31 17:50:00'),
                   msrgp_code: 'PR',
                   msr_type: 'QRC',
                   tar_msr_no: '97060000')
          end

          it_results_in 'P&R Daily Update TAME and TAMF Daily Scenario 2: Restriction removed outcome'
        end
      end

      describe "Daily Scenario 3: Country group changed countries \n" do
        # This scenario describes an update where a restriction on a country group is replaced by a list of countries.
        context 'Alternative 1: Update TAME & TAMF' do
          let!(:us) { create(:geographical_area, geographical_area_id: 'US', geographical_area_sid: 103, validity_start_date: DateTime.parse('1975-07-18 00:00:00')) }
          let!(:cn) { create(:geographical_area, geographical_area_id: 'CN', geographical_area_sid: 439, validity_start_date: DateTime.parse('1975-07-18 00:00:00')) }

          let!(:tame5) do
            create(:tame, :prohibition,
                   amend_indicator: 'U',
                   fe_tsmp: DateTime.parse('2008-05-01 00:00:00'),
                   msrgp_code: 'PR',
                   msr_type: 'CVD',
                   tar_msr_no: '2106909829')
          end

          let!(:tamf5) do
            create(:tamf, :prohibition,
                   amend_indicator: 'U',
                   fe_tsmp: DateTime.parse('2008-05-01 00:00:00'),
                   msrgp_code: 'PR',
                   msr_type: 'CVD',
                   cngp_code: 'US',
                   tar_msr_no: '2106909829')
          end

          let!(:tamf6) do
            create(:tamf, :prohibition,
                   amend_indicator: 'U',
                   fe_tsmp: DateTime.parse('2008-05-01 00:00:00'),
                   msrgp_code: 'PR',
                   msr_type: 'CVD',
                   cngp_code: 'CN',
                   tar_msr_no: '2106909829')
          end

          let!(:tamf7) do
            create(:tamf, :prohibition,
                   amend_indicator: 'U',
                   fe_tsmp: DateTime.parse('2008-05-01 00:00:00'),
                   msrgp_code: 'PR',
                   msr_type: 'CVD',
                   cngp_code: 'IQ',
                   tar_msr_no: '2106909829')
          end

          it_results_in 'P&R Daily Update TAME and TAMF Daily Scenario 3: Country group changed countries outcome'
        end
      end
    end

    describe "Daily Update MFCM \n" do
      describe "Daily Scenario 1: Restriction removed for measure \n" do
        context 'Alternative 1: Update MFCM' do
          let!(:mfcm7) do
            create(:mfcm, :with_goods_nomenclature, :prohibition,
                   amend_indicator: 'U',
                   fe_tsmp: DateTime.parse('2007-10-01 00:00:00'),
                   le_tsmp: DateTime.parse('2008-04-30 15:00:00'),
                   msrgp_code: 'PR',
                   msr_type: 'ATT',
                   tar_msr_no: '1210100010',
                   cmdty_code: '1210100010')
          end

          it_results_in 'P&R Daily Update MFCM Daily Scenario 1: Restriction removed for measure outcome'
        end

        context 'Alternative 2: Delete' do
          let!(:mfcm7) do
            create(:mfcm, :with_goods_nomenclature, :prohibition,
                   amend_indicator: 'X',
                   fe_tsmp: DateTime.parse('2008-04-30 15:00:00'),
                   msrgp_code: 'PR',
                   msr_type: 'ATT',
                   tar_msr_no: '1210100010',
                   cmdty_code: '1210100010')
          end

          it_results_in 'P&R Daily Update MFCM Daily Scenario 1: Restriction removed for measure outcome'
        end

        context 'Alternative 3: Delete & Update TAME/TAMF' do
          let!(:mfcm7) do
            create(:mfcm, :with_goods_nomenclature, :prohibition,
                   amend_indicator: 'U',
                   fe_tsmp: DateTime.parse('2007-10-01 00:00:00'),
                   le_tsmp: DateTime.parse('2008-04-30 15:00:00'),
                   msrgp_code: 'PR',
                   msr_type: 'ATT',
                   tar_msr_no: '1210100010',
                   cmdty_code: '1210100010')
          end

          let!(:tame5) do
            create(:tame, :prohibition,
                   amend_indicator: 'U',
                   fe_tsmp: DateTime.parse('2008-04-01 00:00:00'),
                   le_tsmp: DateTime.parse('2008-04-30 15:00:00'),
                   msrgp_code: 'PR',
                   msr_type: 'ATT',
                   tar_msr_no: '1210100010')
          end

          let!(:tamf5) do
            create(:tamf, :prohibition,
                   amend_indicator: 'U',
                   fe_tsmp: DateTime.parse('2008-04-01 00:00:00'),
                   msrgp_code: 'PR',
                   msr_type: 'ATT',
                   cngp_code: 'XC',
                   tar_msr_no: '1210100010')
          end

          it_results_in 'P&R Daily Update MFCM Daily Scenario 1: Restriction removed for measure outcome'
        end

        context 'Alternative 4: Delete & Delete TAME' do
          let!(:mfcm7) do
            create(:mfcm, :with_goods_nomenclature, :prohibition,
                   amend_indicator: 'X',
                   fe_tsmp: DateTime.parse('2008-04-30 15:00:00'),
                   msrgp_code: 'PR',
                   msr_type: 'ATT',
                   tar_msr_no: '1210100010',
                   cmdty_code: '1210100010')
          end

          let!(:tame5) do
            create(:tame, :prohibition,
                   amend_indicator: 'X',
                   fe_tsmp: DateTime.parse('2008-04-30 15:00:00'),
                   msrgp_code: 'PR',
                   msr_type: 'ATT',
                   tar_msr_no: '1210100010')
          end

          it_results_in 'P&R Daily Update MFCM Daily Scenario 1: Restriction removed for measure outcome'
        end
      end

      describe "Daily Scenario 2: Updated measure with later start date \n" do
        context 'Alternative 1: Update' do
          let!(:mfcm7) do
            create(:mfcm, :with_goods_nomenclature, :prohibition,
                   amend_indicator: 'U',
                   fe_tsmp: DateTime.parse('2008-04-30 15:00:00'),
                   msrgp_code: 'PR',
                   msr_type: 'ATT',
                   tar_msr_no: '1210100010',
                   cmdty_code: '1210100010')
          end

          it_results_in 'P&R Daily Update MFCM Daily Scenario 2: Updated measure with later start date outcome'
        end
      end

      describe "Daily Scenario 3: Restriction applied to wrong commodity removed \n" do
        context 'Alternative 1: Delete MFCM & TAME' do
          let!(:tame5) do
            create(:tame, :prohibition,
                   amend_indicator: 'X',
                   fe_tsmp: DateTime.parse('2006-07-24 08:45:00'),
                   msrgp_code: 'HO',
                   msr_type: 'CON',
                   tar_msr_no: '1211300000')
          end
          let!(:mfcm7) do
            create(:mfcm, :with_goods_nomenclature, :prohibition,
                   amend_indicator: 'X',
                   fe_tsmp: DateTime.parse('2006-07-24 08:45:00'),
                   msrgp_code: 'HO',
                   msr_type: 'CON',
                   tar_msr_no: '1211300000',
                   cmdty_code: '1211300000')
          end

          it_results_in 'P&R Daily Update MFCM Daily Scenario 3: Restriction applied to wrong commodity removed outcome'
        end

        context 'Alternative 2: Delete MFCM' do
          let!(:mfcm7) do
            create(:mfcm, :with_goods_nomenclature, :prohibition,
                   amend_indicator: 'X',
                   fe_tsmp: DateTime.parse('2006-07-24 08:45:00'),
                   msrgp_code: 'HO',
                   msr_type: 'CON',
                   tar_msr_no: '12113000',
                   cmdty_code: '1211300000')
          end

          it_results_in 'P&R Daily Update MFCM Daily Scenario 3: Restriction applied to wrong commodity removed outcome'
        end
      end
    end
  end

  describe 'Daily Update TAME and TAMF' do
    describe "Daily Scenario 4: Country removed from restriction \n" do
      # This scenario describes an update of a restriction where the list of countries is changed to fewer countries.
      # The precondition is the following:
      let!(:us) { create(:geographical_area, geographical_area_id: 'US', geographical_area_sid: 103, validity_start_date: DateTime.parse('1975-07-18 00:00:00')) }
      let!(:cn) { create(:geographical_area, geographical_area_id: 'CN', geographical_area_sid: 439, validity_start_date: DateTime.parse('1975-07-18 00:00:00')) }
      let!(:iq) { create(:geographical_area, geographical_area_id: 'IQ', geographical_area_sid: 666, validity_start_date: DateTime.parse('1975-07-18 00:00:00')) }

      let!(:mfcm7) do
        create(:mfcm, :with_goods_nomenclature,
               :prohibition,
               amend_indicator: 'I',
               fe_tsmp: DateTime.parse('2008-05-01 00:00:00'),
               msrgp_code: 'PR',
               msr_type: 'CVD',
               cmdty_code: '2106909829',
               tar_msr_no: '2106909829')
      end
      let!(:tamf5) do
        create(:tamf, :prohibition,
               amend_indicator: 'I',
               fe_tsmp: DateTime.parse('2008-05-01 00:00:00'),
               msrgp_code: 'PR',
               msr_type: 'CVD',
               cngp_code: 'US',
               tar_msr_no: '2106909829')
      end
      let!(:tamf6) do
        create(:tamf, :prohibition,
               amend_indicator: 'I',
               fe_tsmp: DateTime.parse('2008-05-01 00:00:00'),
               msrgp_code: 'PR',
               msr_type: 'CVD',
               cngp_code: 'CN',
               tar_msr_no: '2106909829')
      end
      let!(:tamf7) do
        create(:tamf, :prohibition,
               amend_indicator: 'I',
               fe_tsmp: DateTime.parse('2008-05-01 00:00:00'),
               msrgp_code: 'PR',
               msr_type: 'CVD',
               cngp_code: 'IQ',
               tar_msr_no: '2106909829')
      end
      let!(:tame5) do
        create(:tame, :prohibition,
               amend_indicator: 'I',
               fe_tsmp: DateTime.parse('2008-05-01 00:00:00'),
               msrgp_code: 'PR',
               msr_type: 'CVD',
               tar_msr_no: '2106909829')
      end
      let!(:mfcm8) do
        create(:mfcm, :with_goods_nomenclature,
               :prohibition,
               amend_indicator: 'X',
               fe_tsmp: DateTime.parse('2008-06-01 00:00:00'),
               msrgp_code: 'PR',
               msr_type: 'CVD',
               cmdty_code: '2106909829',
               tar_msr_no: '2106909829')
      end

      before do
        ChiefTransformer.instance.invoke
      end

      it 'creates three new measures for preconditions with components and footnotes' do
        expect(Measure.count).to eq 3
        m1 = Measure.where(goods_nomenclature_item_id: '2106909829',
                           geographical_area_id: 'US',
                           validity_start_date: DateTime.parse('2008-05-01 00:00:00')).take
        expect(m1.measure_conditions.count).to eq 2
        expect(m1.footnote_association_measures.count).to eq 1
        m2 = Measure.where(goods_nomenclature_item_id: '2106909829',
                           geographical_area_id: 'CN',
                           validity_start_date: DateTime.parse('2008-05-01 00:00:00')).take
        expect(m2.measure_conditions.count).to eq 2
        expect(m2.footnote_association_measures.count).to eq 1
        m3 = Measure.where(goods_nomenclature_item_id: '2106909829',
                           geographical_area_id: 'IQ',
                           validity_start_date: DateTime.parse('2008-05-01 00:00:00')).take
        expect(m3.measure_conditions.count).to eq 2
        expect(m3.footnote_association_measures.count).to eq 1
      end

      it 'creates no excluded countries' do
        expect(MeasureExcludedGeographicalArea.count).to eq 0
      end

      context 'Alternative 1: Update TAME & TAMF' do
        let!(:tamf9) do
          create(:tamf, :prohibition,
                 amend_indicator: 'U',
                 fe_tsmp: DateTime.parse('2008-06-01 00:00:00'),
                 msrgp_code: 'PR',
                 msr_type: 'CVD',
                 cngp_code: 'CN',
                 tar_msr_no: '2106909829')
        end
        let!(:tamf8) do
          create(:tamf, :prohibition,
                 amend_indicator: 'U',
                 fe_tsmp: DateTime.parse('2008-06-01 00:00:00'),
                 msrgp_code: 'PR',
                 msr_type: 'CVD',
                 cngp_code: 'IQ',
                 tar_msr_no: '2106909829')
        end
        let!(:tame6) do
          create(:tame, :prohibition,
                 amend_indicator: 'U',
                 fe_tsmp: DateTime.parse('2008-06-01 00:00:00'),
                 msrgp_code: 'PR',
                 msr_type: 'CVD',
                 tar_msr_no: '2106909829')
        end

        it_results_in 'P&R Daily Update TAME and TAMF Daily Scenario 4: Country removed from restriction outcome'
      end
    end
  end
end
