require 'rails_helper'

describe ChiefTransformer::Processor::TameUpdate do
  before(:all) { preload_standing_data }

  after(:all)  { clear_standing_data }

  let(:sample_operation_date) { Date.new(2013, 8, 5) }

  let(:chief_update) do
    create :chief_update, :applied, issue_date: sample_operation_date
  end

  describe '#process' do
    context 'TAME has last effective date' do
      let(:last_effective_date) { DateTime.parse('2009-11-15 11:00:00') }

      let!(:measure) do
        create :measure,
               :national,
               validity_start_date: DateTime.parse('2008-12-15 11:00:00'),
               goods_nomenclature_item_id: '0101010100',
               measure_type_id: 'VTS'
      end

      let!(:tame) do
        create(:tame, amend_indicator: 'U',
                      fe_tsmp: DateTime.parse('2008-11-15 11:00:00'),
                      le_tsmp: last_effective_date,
                      msrgp_code: 'VT',
                      msr_type: 'S',
                      tty_code: '813',
                      adval_rate: 15.000,
                      origin: chief_update.filename)
      end

      before { ChiefTransformer::Processor::TameUpdate.new(tame).process }

      it 'ends measure setting its validity end date to TAME last effective timestap' do
        expect(measure.reload.validity_end_date.to_date).to eq last_effective_date.to_date
      end
    end
  end
end
