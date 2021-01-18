require 'rails_helper'

describe NationalMeasurementUnitSet do
  describe '#national_measurement_unit_set_units' do
    let(:tbl1) { create :tbl9, :unoq }
    let(:tbl2) { create :tbl9, :unoq }
    let(:tbl3) { create :tbl9, :unoq }
    let(:comm) do
      create :comm, uoq_code_cdu1: tbl1.tbl_code,
                    uoq_code_cdu2: tbl2.tbl_code,
                    uoq_code_cdu3: tbl3.tbl_code
    end

    let(:nmus) { described_class.where(cmdty_code: comm.cmdty_code).first }

    it 'builds array of national measurement units' do
      expect(nmus.national_measurement_unit_set_units).to be_kind_of Array
    end

    it 'includes national measurement units' do
      expect(nmus.national_measurement_unit_set_units).to be_all { |nmusu| nmusu.is_a?(NationalMeasurementUnit) }
    end

    it 'sets first national measurement unit code/description to comm uoq_code_cdu1' do
      nmusu = nmus.national_measurement_unit_set_units.first

      expect(nmusu.measurement_unit_code).to eq tbl1.tbl_code
      expect(nmusu.description).to match(/#{Regexp.escape(tbl1.tbl_txt)}/i)
      expect(nmusu.level).to eq 1
    end

    it 'sets second national measurement unit code/description to comm uoq_code_cdu2' do
      nmusu = nmus.national_measurement_unit_set_units.second

      expect(nmusu.measurement_unit_code).to eq tbl2.tbl_code
      expect(nmusu.description).to match(/#{Regexp.escape(tbl2.tbl_txt)}/i)
      expect(nmusu.level).to eq 2
    end

    it 'sets second national measurement unit code/description to comm uoq_code_cdu3' do
      nmusu = nmus.national_measurement_unit_set_units.last

      expect(nmusu.measurement_unit_code).to eq tbl3.tbl_code
      expect(nmusu.description).to match(/#{Regexp.escape(tbl3.tbl_txt)}/i)
      expect(nmusu.level).to eq 3
    end
  end
end
