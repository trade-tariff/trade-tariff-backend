require 'rails_helper'
require 'chief_transformer'

describe ChiefTransformer::CandidateMeasure::Collection do
  describe '#persist' do
    context 'just MFCM present' do
      let!(:mfcm) { create :mfcm, :for_insert }

      it 'creates no measures' do
        ChiefTransformer.instance.invoke(:initial_load)
        expect(Measure.count).to eq 0
      end

      it 'creates no measure associations' do
        ChiefTransformer.instance.invoke(:initial_load)
        expect(MeasureComponent.count).to eq 0
      end
    end

    context 'MFCM & TAME present' do
      let!(:mfcm) do
        create :mfcm, :for_insert,
               :with_tame_components,
               :with_vat_group,
               :with_geographical_area,
               :with_goods_nomenclature
      end

      it 'create Measure with Measure Components from TAME' do
        ChiefTransformer.instance.invoke(:initial_load)
        expect(Measure.count).to eq 1
        expect(MeasureComponent.count).to eq 1
      end
    end

    context 'MFCM & TAMF present' do
      let!(:chief_duty_expression) do
        create :chief_duty_expression, adval1_rate: 0,
                                       adval2_rate: 0,
                                       spfc1_rate: 1,
                                       spfc2_rate: 0
      end
      let!(:mfcm) do
        create :mfcm, :for_insert,
               :with_tamf_components,
               :with_vat_group,
               :with_geographical_area,
               :with_goods_nomenclature
      end

      it 'creates Measure and Measure Components from TAMF' do
        ChiefTransformer.instance.invoke(:initial_load)
        expect(Measure.count).to eq 1
        expect(MeasureComponent.count).to eq 1
      end

      it 'create Measure Conditions from TAMF' do
        mfcm = create :mfcm, :for_insert,
                      :with_tamf_conditions,
                      :with_goods_nomenclature,
                      msrgp_code: 'PR'

        ChiefTransformer.instance.invoke(:initial_load)
        expect(Measure.count).to eq 2
        expect(MeasureCondition.count).to eq 1
      end
    end
  end

  describe '#uniq' do
    context 'different validity end dates' do
      let!(:mfcm) do
        create :mfcm, :unprocessed,
               cmdty_code: '8452300000',
               msrgp_code: 'VT',
               msr_type: 'S',
               tty_code: 'B00',
               fe_tsmp: DateTime.new(2006, 1, 1)
      end

      let!(:tame1) do
        create :tame, :unprocessed,
               fe_tsmp: DateTime.new(2007, 10, 1),
               le_tsmp: DateTime.new(2008, 12, 1),
               msrgp_code: 'VT',
               msr_type: 'S',
               tty_code: 'B00'
      end

      let!(:tame2) do
        create :tame, :unprocessed,
               fe_tsmp: DateTime.new(2008, 12, 1),
               le_tsmp: DateTime.new(2010, 1, 1),
               msrgp_code: 'VT',
               msr_type: 'S',
               tty_code: 'B00'
      end

      let!(:tame3) do
        create :tame, :unprocessed,
               fe_tsmp: DateTime.new(2010, 1, 1),
               le_tsmp: DateTime.new(2011, 1, 4),
               msrgp_code: 'VT',
               msr_type: 'S',
               tty_code: 'B00'
      end

      let!(:tame4) do
        create :tame, :unprocessed,
               fe_tsmp: DateTime.new(2011, 1, 4),
               msrgp_code: 'VT',
               msr_type: 'S',
               tty_code: 'B00'
      end

      let(:candidate_measures) do
        ChiefTransformer::CandidateMeasure::Collection.new(mfcm.tames.map do |tame|
          ChiefTransformer::CandidateMeasure.new(mfcm: mfcm, tame: tame)
        end)
      end

      it 'validity end dates differentiate measures' do
        expect(candidate_measures.uniq.size).to eq mfcm.tames.size
      end
    end

    context 'same validity end dates' do
      let!(:mfcm) do
        create :mfcm, :unprocessed,
               cmdty_code: '8452300000',
               msrgp_code: 'VT',
               msr_type: 'S',
               tty_code: 'B00',
               fe_tsmp: DateTime.new(2012, 1, 1)
      end

      let!(:tame1) do
        create :tame, :unprocessed,
               fe_tsmp: DateTime.new(2007, 10, 1),
               msrgp_code: 'VT',
               msr_type: 'S',
               tty_code: 'B00'
      end

      let!(:tame2) do
        create :tame, :unprocessed,
               fe_tsmp: DateTime.new(2008, 12, 1),
               msrgp_code: 'VT',
               msr_type: 'S',
               tty_code: 'B00'
      end

      let!(:tame3) do
        create :tame, :unprocessed,
               fe_tsmp: DateTime.new(2010, 1, 1),
               msrgp_code: 'VT',
               msr_type: 'S',
               tty_code: 'B00'
      end

      let!(:tame4) do
        create :tame, :unprocessed,
               fe_tsmp: DateTime.new(2011, 1, 4),
               msrgp_code: 'VT',
               msr_type: 'S',
               tty_code: 'B00'
      end

      let(:candidate_measures) do
        ChiefTransformer::CandidateMeasure::Collection.new(mfcm.tames.map do |tame|
          ChiefTransformer::CandidateMeasure.new(mfcm: mfcm, tame: tame)
        end)
      end

      it 'removes duplicate measures' do
        expect(candidate_measures.uniq.size).to eq 1
      end
    end
  end
end
