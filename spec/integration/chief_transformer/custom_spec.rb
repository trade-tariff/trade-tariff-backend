require 'rails_helper'
require 'goods_nomenclature'
require 'chief_transformer'

describe 'CHIEF: Custom scenarios' do
  before(:all) { preload_standing_data }

  after(:all)  { clear_standing_data }

  # Based on real data
  describe 'Scenario: TARIC update invalidates CHIEF measures' do
    let!(:measure_type)       { create :measure_type, measure_type_id: 'CVD' }
    let!(:geographical_area)  { build :geographical_area, :erga_omnes }
    let!(:goods_nomenclature) do
      create :goods_nomenclature, :declarable,
             :with_indent,
             goods_nomenclature_item_id: '1604141620',
             goods_nomenclature_sid: 70_180,
             producline_suffix: '80',
             validity_start_date: DateTime.parse('1998-07-14 00:00:00 -0700'),
             validity_end_date: nil
    end
    let!(:goods_nomenclature_indent) do
      create :goods_nomenclature_indent, number_indents: 10,
                                         validity_start_date: DateTime.parse('1998-07-14 00:00:00 -0700'),
                                         goods_nomenclature_sid: goods_nomenclature.goods_nomenclature_sid,
                                         goods_nomenclature_item_id: goods_nomenclature.goods_nomenclature_item_id
    end
    let(:national_measure) do
      create :measure, :national, measure_type_id: measure_type.measure_type_id,
                                  goods_nomenclature: goods_nomenclature,
                                  geographical_area: geographical_area,
                                  tariff_measure_number: goods_nomenclature.goods_nomenclature_item_id,
                                  validity_start_date: DateTime.parse('2012-03-01 00:00:00 +0200')
    end

    specify 'national measure is valid before update' do
      expect(national_measure.valid?).to be_truthy
    end

    context 'Taric update occurs' do
      let(:transaction_id) { 13_565_498 }
      let(:operation_date) { Date.new(2013, 8, 5) }

      # Update goods nomenclature effectively leaving national measure invalid!
      # As goods_nomenclature now does not span the validity period of national_measure (ME8)
      def perform_transaction
        transaction_record = {
          'transaction_id' => transaction_id,
          'record_code' => '400',
          'subrecord_code' => '00',
          'record_sequence_number' => '199',
          'update_type' => '1',
          'goods_nomenclature' => {
            'goods_nomenclature_sid' => '70180',
            'goods_nomenclature_item_id' => '1604141620',
            'producline_suffix' => '80',
            'validity_start_date' => '1998-07-14',
            'validity_end_date' => '2011-12-31',
            'statistical_indicator' => '0',
          },

        }

        TaricImporter::RecordProcessor.new(transaction_record, operation_date).process!
      end

      specify 'sets national measures invalidate_by to Taric transaction number' do
        national_measure

        perform_transaction

        expect(national_measure.reload.invalidated_by).to eq transaction_id
        expect(national_measure.valid?).to be_truthy
      end

      specify 'sets goods nomenclature update date to operation date' do
        national_measure

        perform_transaction

        expect(
          GoodsNomenclature::Operation.where(
            goods_nomenclature_sid: goods_nomenclature.goods_nomenclature_sid,
            operation: 'U',
          ).first.operation_date,
        ).to eq operation_date
      end
    end
  end

  describe 'Scenario: TARIC deletion invalidates CHIEF measures' do
    let!(:measure_type)       { create :measure_type, measure_type_id: 'CVD' }
    let!(:geographical_area)  { build :geographical_area, :erga_omnes }
    let!(:goods_nomenclature) do
      create :commodity, :declarable,
             :with_indent,
             goods_nomenclature_item_id: '0305720040',
             goods_nomenclature_sid: 96_196,
             validity_start_date: DateTime.parse('2012-01-01 00:00:00 -0700'),
             validity_end_date: nil
    end
    let!(:goods_nomenclature_indent) do
      create :goods_nomenclature_indent, number_indents: 10,
                                         validity_start_date: DateTime.parse('2012-01-01 00:00:00 -0700'),
                                         goods_nomenclature_sid: goods_nomenclature.goods_nomenclature_sid,
                                         goods_nomenclature_item_id: goods_nomenclature.goods_nomenclature_item_id
    end
    let(:national_measure) do
      create :measure, :national, measure_type_id: measure_type.measure_type_id,
                                  goods_nomenclature: goods_nomenclature,
                                  geographical_area: geographical_area,
                                  tariff_measure_number: goods_nomenclature.goods_nomenclature_item_id,
                                  validity_start_date: DateTime.parse('2012-07-01 00:00:00 +0200')
    end

    specify 'national measure is valid before update' do
      expect(national_measure.valid?).to be_truthy
    end

    context 'Taric update occurs' do
      let(:transaction_id) { 13_590_603 }
      let(:operation_date) { Date.new(2013, 8, 5) }

      # Goods Nomenclature deletion Makes national measures invalid.
      def perform_transaction
        transaction_record = {
          'transaction_id' => transaction_id,
          'record_code' => '400',
          'subrecord_code' => '00',
          'record_sequence_number' => '00',
          'update_type' => '2',
          'goods_nomenclature' => {
            'goods_nomenclature_sid' => '96196',
            'goods_nomenclature_item_id' => '0305720040',
            'producline_suffix' => '80',
            'validity_start_date' => '2012-01-01',
            'statistical_indicator' => '0',
          },
        }

        TaricImporter::RecordProcessor.new(transaction_record, operation_date).process!
      end

      before do
        national_measure

        perform_transaction
      end

      specify 'sets national measures invalidate_by to Taric transaction number' do
        expect(national_measure.reload.invalidated_by).to eq transaction_id
        expect(national_measure.valid?).to be_truthy
      end

      specify 'deletes goods nomenclature' do
        expect { goods_nomenclature.reload }.to raise_error(Sequel::Error)
      end

      specify 'sets goods nomenclature destroy date to operation date' do
        expect(
          GoodsNomenclature::Operation.where(
            goods_nomenclature_sid: goods_nomenclature.goods_nomenclature_sid,
            operation: 'D',
          ).first.operation_date,
        ).to eq operation_date
      end
    end
  end

  # Based on real data
  describe 'Scenario: TAME deletion yields national measure invalid' do
    let!(:gono) do
      create :goods_nomenclature, :with_indent,
             goods_nomenclature_sid: 86_487,
             goods_nomenclature_item_id: '1211908500',
             producline_suffix: '80',
             validity_start_date: Date.new(2007, 1, 1),
             validity_end_date: Date.new(2012, 12, 13)
    end
    let!(:measure) do
      create :measure, :national, measure_sid: -262_016,
                                  measure_type_id: 'COE',
                                  goods_nomenclature: gono,
                                  validity_start_date: DateTime.new(2012, 7, 25, 11, 1),
                                  validity_end_date: nil,
                                  tariff_measure_number: '12110985'
    end
    let!(:measure_type) { create :measure_type, measure_type_id: 'COE' }
    let!(:tame) do
      create :tame, fe_tsmp: DateTime.new(2013, 1, 1),
                    msrgp_code: 'HO',
                    msr_type: 'CON',
                    tty_code: nil,
                    tar_msr_no: '12110985',
                    le_tsmp: nil,
                    processed: false,
                    amend_indicator: 'X'
    end

    before do
      ChiefTransformer.instance.invoke
    end

    it 'sets measure validity end date to gono validity end date' do
      # so that ME8 validation on Measure is kept valid
      expect(measure.reload.validity_end_date).to eq gono.validity_end_date
      expect(measure.validity_end_date).not_to eq tame.fe_tsmp
    end
  end

  describe 'Scenario: MFCM update fails due to conformance validation (ME8)' do
    let!(:gono) do
      create :goods_nomenclature, :declarable, :with_indent,
             goods_nomenclature_sid: 91_900,
             goods_nomenclature_item_id: '5607509090',
             producline_suffix: '80',
             validity_start_date: Date.new(2010, 1, 1),
             validity_end_date: Date.new(2013, 2, 28)
    end
    let!(:measure) do
      create :measure, :national, measure_sid: -41_534,
                                  measure_type_id: 'VTS',
                                  goods_nomenclature: gono,
                                  goods_nomenclature_sid: gono.goods_nomenclature_sid,
                                  goods_nomenclature_item_id: gono.goods_nomenclature_item_id,
                                  validity_start_date: DateTime.new(2007, 10, 1, 0, 0),
                                  validity_end_date: Date.new(2013, 2, 28),
                                  tariff_measure_number: '12110985'
    end

    let!(:mfcm) do
      create :mfcm, msrgp_code: 'VT',
                    msr_type: 'S',
                    tty_code: 'B00',
                    fe_tsmp: DateTime.new(2013, 5, 14, 14, 14),
                    le_tsmp: DateTime.new(2013, 5, 14, 14, 28),
                    cmdty_code: '5607509090',
                    tar_msr_no: nil,
                    amend_indicator: 'U'
    end

    let!(:measure_type) { create :measure_type, measure_type_id: 'VTS', validity_start_date: Date.current.ago(10.years) }

    it 'will not raise validation exception' do
      expect { ChiefTransformer.instance.invoke }.not_to raise_error
    end

    it 'will update measure validity dates' do
      ChiefTransformer.instance.invoke

      expect(measure.reload.validity_end_date).to eq mfcm.le_tsmp
    end

    it 'will mark measure as invalidated' do
      ChiefTransformer.instance.invoke

      expect(measure.reload).to be_invalidated
    end
  end

  describe 'Scenario: single CHIEF update contains MFCM Insert and Update operations' do
    let!(:geographical_area) { create :geographical_area, :erga_omnes, validity_start_date: DateTime.new(2010, 2, 22, 12, 27) }
    let!(:gono) do
      create :goods_nomenclature, :declarable, :with_indent,
             goods_nomenclature_sid: 97_701,
             goods_nomenclature_item_id: '1104291710',
             producline_suffix: '80',
             validity_start_date: Date.new(2013, 7, 1),
             validity_end_date: nil
    end

    let!(:tame) do
      create :tame,
             fe_tsmp: DateTime.new(2010, 2, 22, 12, 27),
             msrgp_code: 'VT',
             msr_type: 'Z',
             tty_code: 'B00',
             le_tsmp: nil
    end

    let!(:mfcm_insert) do
      create :mfcm, msrgp_code: 'VT',
                    msr_type: 'Z',
                    tty_code: 'B00',
                    fe_tsmp: DateTime.new(2013, 7, 10, 10, 27, 0o0),
                    le_tsmp: DateTime.new(2013, 7, 10, 10, 28, 0o0),
                    audit_tsmp: DateTime.new(2013, 7, 10, 10, 26, 0o0),
                    cmdty_code: '1104291710',
                    tar_msr_no: nil,
                    origin: '2013-07-11_KBT009(13192).txt',
                    amend_indicator: 'I'
    end
    let!(:mfcm_update) do
      create :mfcm, msrgp_code: 'VT',
                    msr_type: 'Z',
                    tty_code: 'B00',
                    fe_tsmp: DateTime.new(2013, 7, 10, 10, 28, 0o0),
                    audit_tsmp: DateTime.new(2013, 7, 10, 10, 26, 0o0),
                    le_tsmp: nil,
                    cmdty_code: '1104291710',
                    tar_msr_no: nil,
                    origin: '2013-07-11_KBT009(13192).txt',
                    amend_indicator: 'U'
    end

    before do
      ChiefTransformer.instance.invoke(
        :update,
        double('chief_update', filename: '2013-07-11_KBT009(13192).txt'),
      )
    end

    it 'creates a short lived VTZ measure for 1104291710' do
      expect(
        Measure.national.where(
          goods_nomenclature_item_id: '1104291710',
          validity_start_date: DateTime.new(2013, 7, 10, 10, 27),
          validity_end_date: DateTime.new(2013, 7, 10, 10, 28),
          measure_type_id: 'VTZ',
        ).any?,
      ).to be_truthy
    end

    it 'creates an open VTZ measure for 1104291710' do
      expect(
        Measure.national.where(
          goods_nomenclature_item_id: '1104291710',
          validity_start_date: DateTime.new(2013, 7, 10, 10, 28),
          validity_end_date: nil,
          measure_type_id: 'VTZ',
        ).any?,
      ).to be_truthy
    end
  end

  describe 'Scenario: measure associated to CHIEF country group' do
    let!(:tamf) do
      create :tamf, fe_tsmp: DateTime.new(2011, 4, 1),
                    msrgp_code: 'DP',
                    msr_type: 'DPO',
                    tty_code: nil,
                    tar_msr_no: '61113010',
                    cngp_code: 'B110',
                    amend_indicator: 'I'
    end
    let!(:tame) do
      create :tame, fe_tsmp: DateTime.new(2011, 4, 1),
                    le_tsmp: DateTime.new(2011, 7, 1),
                    msrgp_code: 'DP',
                    msr_type: 'DPO',
                    tty_code: nil,
                    tar_msr_no: '61113010',
                    amend_indicator: 'I'
    end
    let!(:mfcm) do
      create :mfcm, fe_tsmp: DateTime.new(1997, 7, 1),
                    msrgp_code: 'DP',
                    msr_type: 'DPO',
                    tty_code: nil,
                    le_tsmp: DateTime.new(2011, 10, 25),
                    cmdty_code: '6111301000',
                    tar_msr_no: '61113010',
                    amend_indicator: 'I'
    end
    let!(:gono) do
      create :goods_nomenclature, :declarable, :with_indent,
             goods_nomenclature_sid: 97_701,
             goods_nomenclature_item_id: '6111301000',
             producline_suffix: '80',
             validity_start_date: Date.new(1999, 7, 1),
             validity_end_date: nil
    end
    let!(:national_geographical_area) do
      create :geographical_area, geographical_area_id: 'B110', validity_start_date: Date.new(1999, 7, 1),
                                 validity_end_date: nil
    end
    let!(:geographical_area) do
      create :geographical_area, :erga_omnes, validity_start_date: Date.new(1999, 7, 1),
                                              validity_end_date: nil
    end

    specify 'CHIEF country group gets converted to TARIC country group' do
      ChiefTransformer.instance.invoke(:initial_load)
      expect(
        Measure.national.where(
          goods_nomenclature_item_id: '6111301000',
          measure_type_id: 'DPO',
          geographical_area_id: '1011', # erga omnes
        ).any?,
      ).to be_truthy
    end
  end

  describe 'Scenario: Excise Measure with duty type 30 and tty code 570, 571, created measure' do
    let!(:geographical_area) { create :geographical_area, :erga_omnes, validity_start_date: DateTime.new(2013, 10, 1) }
    let!(:gono) do
      create :goods_nomenclature, :declarable, :with_indent,
             goods_nomenclature_sid: 79_289,
             goods_nomenclature_item_id: '3902200010',
             producline_suffix: '80',
             validity_start_date: Date.new(1999, 7, 1),
             validity_end_date: nil
    end
    let!(:mfcm) do
      create :mfcm, msrgp_code: 'EX',
                    msr_type: 'EXL',
                    tty_code: '551',
                    fe_tsmp: DateTime.new(2013, 10, 1),
                    le_tsmp: nil,
                    cmdty_code: '3902200010',
                    amend_indicator: 'I'
    end
    let!(:tame) do
      create :tame, fe_tsmp: DateTime.new(1994, 4, 7),
                    le_tsmp: nil,
                    msrgp_code: 'EX',
                    msr_type: 'EXL',
                    tty_code: '551',
                    amend_indicator: 'I'
    end
    let!(:tamf) do
      create :tamf, fe_tsmp: DateTime.new(1994, 4, 7),
                    msrgp_code: 'EX',
                    msr_type: 'EXL',
                    tty_code: '551',
                    duty_type: '30',
                    spfc1_uoq: '070',
                    amend_indicator: 'I'
    end

    let(:measure) do
      Measure.where(
        measure_type_id: 'LEA',
        goods_nomenclature_item_id: '3902200010',
      ).take
    end

    before do
      ChiefTransformer.instance.invoke
    end

    specify 'measure gets created' do
      expect(
        Measure.where(
          measure_type_id: 'LEA',
          goods_nomenclature_item_id: '3902200010',
        ),
      ).to be_present
    end

    specify 'has zero rate' do
      expect(
        MeasureComponent.where(
          measure_sid: measure.measure_sid,
        ).take.duty_amount,
      ).to eq 0
    end

    specify 'has GBP as monetary unit' do
      expect(
        MeasureComponent.where(
          measure_sid: measure.measure_sid,
        ).take.monetary_unit_code,
      ).to eq 'GBP'
    end

    specify 'has LTR as measurement unit' do
      expect(
        MeasureComponent.where(
          measure_sid: measure.measure_sid,
        ).take.measurement_unit_code,
      ).to eq 'LTR'
    end
  end
end
