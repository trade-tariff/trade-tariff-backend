require 'rails_helper'

describe ChiefTransformer::Processor::MfcmDelete do
  before(:all) { preload_standing_data }

  after(:all)  { clear_standing_data }

  let(:sample_operation_date) { Date.new(2013, 8, 5) }

  let(:chief_update) do
    create :chief_update, :applied, issue_date: sample_operation_date
  end

  describe '#process' do
    context 'affected measures present' do
      let(:goods_nomenclature) { create :commodity, goods_nomenclature_item_id: '0101010100' }

      let!(:measure) do
        create :measure,
               national: true,
               validity_start_date: DateTime.parse('2006-11-15 11:00:00'),
               goods_nomenclature: goods_nomenclature,
               goods_nomenclature_item_id: '0101010100',
               goods_nomenclature_sid: goods_nomenclature.goods_nomenclature_sid,
               measure_type_id: 'VTS'
      end

      let!(:mfcm) do
        create(:mfcm, amend_indicator: 'X',
                      fe_tsmp: DateTime.parse('2007-11-15 11:00:00'),
                      msrgp_code: 'VT',
                      msr_type: 'S',
                      tty_code: '813',
                      cmdty_code: '0101010100',
                      origin: chief_update.filename)
      end

      before do
        ChiefTransformer::Processor::MfcmDelete.new(mfcm).process
      end

      it 'adds default national justification regulation to affected measures' do
        expect(
          Measure::Operation.where(
            goods_nomenclature_item_id: '0101010100',
            national: true,
            measure_type_id: 'VTS',
            operation: 'U',
            operation_date: sample_operation_date,
          ).where(
            Sequel.~(
              justification_regulation_id: nil,
              justification_regulation_role: nil,
            ),
          ).one?,
        ).to be_truthy
      end
    end

    context 'associated to non open ended goods_nomenclature' do
      context 'MFCM record fe_tsmp greater than goods_nomenclature validity start date' do
        let!(:mfcm) do
          create(:mfcm, amend_indicator: 'X',
                        fe_tsmp: DateTime.parse('2007-11-15 11:00:00'),
                        msrgp_code: 'VT',
                        msr_type: 'S',
                        tty_code: '813',
                        cmdty_code: '0101010100',
                        origin: chief_update.filename)
        end

        let(:goods_nomenclature) do
          create :commodity,
                 goods_nomenclature_item_id: '0101010100',
                 validity_start_date: DateTime.parse('2006-1-15 11:00:00'),
                 validity_end_date: DateTime.parse('2006-12-15 11:00:00')
        end

        let!(:measure) do
          create :measure,
                 national: true,
                 validity_start_date: DateTime.parse('2006-11-15 11:00:00'),
                 goods_nomenclature: goods_nomenclature,
                 goods_nomenclature_item_id: '0101010100',
                 goods_nomenclature_sid: goods_nomenclature.goods_nomenclature_sid,
                 measure_type_id: 'VTS'
        end

        before do
          ChiefTransformer::Processor::MfcmDelete.new(mfcm).process
        end

        it 'adds validity end date of goods_nomenclature validity_end_date to affected measure' do
          expect(
            Measure::Operation.where(
              goods_nomenclature_item_id: '0101010100',
              validity_end_date: DateTime.parse('2006-12-15 11:00:00'),
              national: true,
              measure_type_id: 'VTS',
              operation: 'U',
              operation_date: sample_operation_date,
            ).one?,
          ).to be_truthy
        end
      end

      context 'MFCM record fe_tsmp not greater than goods_nomenclature validity start date' do
        let!(:mfcm) do
          create(:mfcm, amend_indicator: 'X',
                        fe_tsmp: DateTime.parse('2007-11-15 11:00:00'),
                        msrgp_code: 'VT',
                        msr_type: 'S',
                        tty_code: '813',
                        cmdty_code: '0101010100',
                        origin: chief_update.filename)
        end

        let(:goods_nomenclature) do
          create :commodity,
                 goods_nomenclature_item_id: '0101010100',
                 validity_start_date: DateTime.parse('2006-1-15 11:00:00'),
                 validity_end_date: DateTime.parse('2008-12-15 11:00:00')
        end

        let!(:measure) do
          create :measure,
                 national: true,
                 validity_start_date: DateTime.parse('2006-11-15 11:00:00'),
                 goods_nomenclature: goods_nomenclature,
                 goods_nomenclature_item_id: '0101010100',
                 goods_nomenclature_sid: goods_nomenclature.goods_nomenclature_sid,
                 measure_type_id: 'VTS'
        end

        before do
          ChiefTransformer::Processor::MfcmDelete.new(mfcm).process
        end

        it 'adds validity end date of MFCM fe_tsmp to affected measure' do
          expect(
            Measure::Operation.where(
              goods_nomenclature_item_id: '0101010100',
              validity_end_date: DateTime.parse('2007-11-15 11:00:00'),
              national: true,
              measure_type_id: 'VTS',
              operation: 'U',
              operation_date: sample_operation_date,
            ).one?,
          ).to be_truthy
        end
      end
    end

    context 'associated to open ended goods nomenclature' do
      let!(:mfcm) do
        create(:mfcm, amend_indicator: 'X',
                      fe_tsmp: DateTime.parse('2007-11-15 11:00:00'),
                      msrgp_code: 'VT',
                      msr_type: 'S',
                      tty_code: '813',
                      cmdty_code: '0101010100',
                      origin: chief_update.filename)
      end

      let(:goods_nomenclature) do
        create :commodity,
               goods_nomenclature_item_id: '0101010100',
               validity_start_date: DateTime.parse('2006-1-15 11:00:00'),
               validity_end_date: nil
      end

      let!(:measure) do
        create :measure,
               national: true,
               validity_start_date: DateTime.parse('2006-11-15 11:00:00'),
               goods_nomenclature: goods_nomenclature,
               goods_nomenclature_item_id: '0101010100',
               goods_nomenclature_sid: goods_nomenclature.goods_nomenclature_sid,
               measure_type_id: 'VTS'
      end

      before do
        ChiefTransformer::Processor::MfcmDelete.new(mfcm).process
      end

      it 'adds validity end date of MFCM fe_tsmp to affected measure' do
        expect(
          Measure::Operation.where(
            goods_nomenclature_item_id: '0101010100',
            validity_end_date: DateTime.parse('2007-11-15 11:00:00'),
            national: true,
            measure_type_id: 'VTS',
            operation: 'U',
            operation_date: sample_operation_date,
          ).one?,
        ).to be_truthy
      end
    end
  end
end
