require 'rails_helper'

describe Chief::Tamf do
  describe 'associations' do
    describe 'measure_type_conds' do
      let!(:common) { attributes_for(:measure_type_cond) }
      let!(:tamf)   { create :tamf, msrgp_code: common[:measure_group_code], msr_type: common[:measure_type] }
      let!(:measure_type_cond) { create :measure_type_cond, common }
      let!(:measure_type_cond_irrelevant) { create :measure_type_cond }

      it 'associates correct Chief measure type conditions' do
        expect(tamf.measure_type_conds).to     include measure_type_cond
        expect(tamf.measure_type_conds).not_to include measure_type_cond_irrelevant
      end
    end
  end

  describe '#mark_as_processed!' do
    let!(:tamf) { create :tamf }

    it 'marks itself as processed' do
      expect(tamf.processed).to be_falsy
      tamf.mark_as_processed!
      expect(tamf.reload.processed).to be_truthy
    end
  end

  describe '#geographical_area' do
    before { Chief::Tamf.unrestrict_primary_key }

    it 'picks cngp_code if it is available' do
      tamf = Chief::Tamf.new(cngp_code: 'abc')
      expect(tamf.geographical_area).to eq 'abc'
    end

    it 'picks cntry_orig if cngp_code is unavailable' do
      tamf = Chief::Tamf.new(cntry_orig: 'abc')
      expect(tamf.geographical_area).to eq 'abc'
    end

    it 'picks cntry_disp if cngp_cod and cntry_orig are unavailable' do
      tamf = Chief::Tamf.new(cntry_disp: 'abc')
      expect(tamf.geographical_area).to eq 'abc'
    end
  end

  describe '#measurement_unit' do
    let!(:chief_measurement_unit1) do
      create :chief_measurement_unit, spfc_cmpd_uoq: '12',
                                      spfc_uoq: '13'
    end
    let!(:chief_measurement_unit2) do
      create :chief_measurement_unit, spfc_cmpd_uoq: nil,
                                      spfc_uoq: '13'
    end
    let(:tamf) { build :tamf }

    context 'cmpd_uoq present' do
      it 'fetches Chief::MeasurementUnit with cmpd_uoq as part of the key' do
        expect(
          tamf.measurement_unit('12', '13'),
        ).to eq chief_measurement_unit1
      end
    end

    context 'cmpd_uoq blank' do
      it 'fetches Chief::MeasurementUnit with uoq as key' do
        expect(
          tamf.measurement_unit(nil, '13'),
        ).to eq chief_measurement_unit2
      end
    end
  end
end
