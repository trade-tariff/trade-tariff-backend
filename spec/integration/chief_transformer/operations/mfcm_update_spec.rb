require 'rails_helper'

describe ChiefTransformer::Processor::MfcmUpdate do
  before(:all) { preload_standing_data }

  after(:all)  { clear_standing_data }

  let(:sample_operation_date) { Date.new(2013, 8, 5) }

  let(:chief_update) do
    create :chief_update, :applied, issue_date: sample_operation_date
  end

  describe '#process' do
    context 'MFCM contains last effective date' do
      context 'there are measure valid until MFCM last effective date' do
        let!(:measure) do
          create :measure,
                 national: true,
                 validity_start_date: DateTime.parse('2006-11-15 11:00:00'),
                 goods_nomenclature_item_id: '0101010100',
                 measure_type_id: 'VTS'
        end

        let!(:mfcm) do
          create(:mfcm, amend_indicator: 'U',
                        fe_tsmp: DateTime.parse('2002-11-15 11:00:00'),
                        le_tsmp: DateTime.parse('2008-11-15 11:00:00'),
                        msrgp_code: 'VT',
                        msr_type: 'S',
                        tty_code: '813',
                        cmdty_code: '0101010100',
                        origin: chief_update.filename)
        end

        before do
          ChiefTransformer::Processor::MfcmUpdate.new(mfcm).process
        end

        it 'ends affected measures' do
          expect(
            Measure::Operation.where(
              goods_nomenclature_item_id: '0101010100',
              national: true,
              measure_type_id: 'VTS',
              operation: 'U',
              operation_date: sample_operation_date,
              validity_end_date: mfcm.le_tsmp,
            ).where(
              Sequel.~(
                justification_regulation_id: nil,
                justification_regulation_role: nil,
              ),
            ).one?,
          ).to be_truthy
        end
      end

      context 'there are no measures valid until MFCM last effective date' do
        let!(:measure) do
          create :measure,
                 national: true,
                 validity_start_date: DateTime.parse('2009-11-15 11:00:00'),
                 goods_nomenclature_item_id: '0101010100',
                 measure_type_id: 'VTS'
        end

        let!(:mfcm) do
          create(:mfcm, amend_indicator: 'U',
                        fe_tsmp: DateTime.parse('2002-11-15 11:00:00'),
                        le_tsmp: DateTime.parse('2008-11-15 11:00:00'),
                        msrgp_code: 'VT',
                        msr_type: 'S',
                        tty_code: '813',
                        cmdty_code: '0101010100',
                        origin: chief_update.filename)
        end

        before do
          ChiefTransformer::Processor::MfcmUpdate.new(mfcm).process
        end

        it 'does not change measures' do
          expect(
            Measure::Operation.where(
              goods_nomenclature_item_id: '0101010100',
              national: true,
              measure_type_id: 'VTS',
              operation: 'C',
              validity_end_date: nil,
              justification_regulation_id: nil,
              justification_regulation_role: nil,
            ).one?,
          ).to be_truthy
        end
      end
    end

    context 'MFCM does not contain last effective date' do
      context 'there are relevant terminated measures that expired be MFCM first effective date' do
        let!(:measure) do
          create :measure,
                 national: true,
                 validity_start_date: DateTime.parse('2006-11-15 11:00:00'),
                 validity_end_date: DateTime.parse('2007-11-15 11:00:00'),
                 goods_nomenclature_item_id: '0101010100',
                 measure_type_id: 'VTS'
        end

        let!(:mfcm) do
          create(:mfcm, amend_indicator: 'U',
                        fe_tsmp: DateTime.parse('2008-11-15 11:00:00'),
                        le_tsmp: nil,
                        msrgp_code: 'VT',
                        msr_type: 'S',
                        tty_code: '813',
                        cmdty_code: '0101010100',
                        origin: chief_update.filename)
        end

        let!(:tame) do
          create(:tame, amend_indicator: 'U',
                        fe_tsmp: DateTime.parse('2008-11-15 11:00:00'),
                        msrgp_code: 'VT',
                        msr_type: 'S',
                        tty_code: '813',
                        adval_rate: 15.000,
                        origin: chief_update.filename)
        end

        let!(:geographical_area) { create :geographical_area, :fifteen_years, :erga_omnes }

        before do
          ChiefTransformer::Processor::MfcmUpdate.new(mfcm).process
        end

        it 'creates new measures for new validity period' do
          expect(
            Measure::Operation.where(
              goods_nomenclature_item_id: '0101010100',
              national: true,
              measure_type_id: 'VTS',
              operation: 'C',
              validity_start_date: mfcm.fe_tsmp,
              validity_end_date: nil,
              justification_regulation_id: nil,
              justification_regulation_role: nil,
            ).one?,
          ).to be_truthy
        end
      end

      context 'there are no relevant terminated measures that expired be MFCM first effective date' do
        let!(:measure) do
          create :measure,
                 national: true,
                 validity_start_date: DateTime.parse('2006-11-15 11:00:00'),
                 validity_end_date: nil, # not terminated
                 goods_nomenclature_item_id: '0101010100',
                 measure_type_id: 'VTS'
        end

        let!(:mfcm) do
          create(:mfcm, amend_indicator: 'U',
                        fe_tsmp: DateTime.parse('2008-11-15 11:00:00'),
                        le_tsmp: nil,
                        msrgp_code: 'VT',
                        msr_type: 'S',
                        tty_code: '813',
                        cmdty_code: '0101010100',
                        origin: chief_update.filename)
        end

        let!(:tame) do
          create(:tame, amend_indicator: 'U',
                        fe_tsmp: DateTime.parse('2008-11-15 11:00:00'),
                        msrgp_code: 'VT',
                        msr_type: 'S',
                        tty_code: '813',
                        adval_rate: 15.000,
                        origin: chief_update.filename)
        end

        let!(:geographical_area) { create :geographical_area, :fifteen_years, :erga_omnes }

        it 'does not create new measures' do
          expect { ChiefTransformer::Processor::MfcmUpdate.new(mfcm).process }.not_to change(Measure, :count)
        end
      end
    end
  end
end
