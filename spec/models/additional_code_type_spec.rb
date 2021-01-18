require 'rails_helper'

describe AdditionalCodeType do
  describe 'validations' do
    # CT1 The additional code type must be unique.
    it { is_expected.to validate_uniqueness.of :additional_code_type_id }
    # CT4 The start date must be less than or equal to the end date.
    it { is_expected.to validate_validity_dates }

    describe 'CT2' do
      context 'meursing table plan id present' do
        context 'application code is meursing table plan additional code type' do
          let!(:additional_code_type) do
            build :additional_code_type, :with_meursing_table_plan,
                  :meursing
          end

          it 'is valid' do
            expect(additional_code_type).to be_conformant
          end
        end

        context 'application code is not meursing table plan additional code type' do
          let!(:additional_code_type) do
            build :additional_code_type, :with_meursing_table_plan,
                  :adco
          end

          it 'is not valid' do
            expect(additional_code_type).not_to be_conformant
          end
        end
      end

      context 'meursing table plan id missing' do
        let!(:additional_code_type) { build :additional_code_type, :adco }

        it 'is valid' do
          expect(additional_code_type).to be_conformant
        end
      end
    end

    describe 'CT3' do
      context 'meursing table plan exists' do
        let!(:additional_code_type) do
          build :additional_code_type, :with_meursing_table_plan,
                :meursing
        end

        it 'is valid' do
          expect(additional_code_type).to be_valid
        end
      end

      context 'meursing table plan does not exist' do
        let!(:additional_code_type) { build :additional_code_type, meursing_table_plan_id: 'XX' }

        it 'is not valid' do
          expect(additional_code_type).not_to be_conformant
        end
      end
    end

    describe 'CT6' do
      context 'non meursing additional code' do
        let!(:additional_code_type) { create :additional_code_type }
        let!(:additional_code)      { create :additional_code, additional_code_type_id: additional_code_type.additional_code_type_id }

        before do
          additional_code_type.destroy
          additional_code_type.conformant?
        end

        specify 'The additional code type cannot be deleted if it is related with a non-Meursing additional code.' do
          expect(additional_code_type.conformance_errors.keys).to include :CT6
        end
      end

      context 'meursing additional code' do
        let!(:additional_code_type) { create :additional_code_type }
        let!(:additional_code)      { create :additional_code, additional_code_type_id: additional_code_type.additional_code_type_id }
        let!(:meursing_additional_code) { create :meursing_additional_code, additional_code: additional_code.additional_code }

        before do
          additional_code_type.destroy
          additional_code_type.conformant?
        end

        specify 'The additional code type cannot be deleted if it is related with a non-Meursing additional code.' do
          expect(additional_code_type.conformance_errors.keys).not_to include :CT6
        end
      end
    end

    describe 'CT7' do
      let(:additional_code_type) { create :additional_code_type, :with_meursing_table_plan }

      before do
        additional_code_type.destroy
        additional_code_type.conformant?
      end

      specify 'The additional code type cannot be deleted if it is related with a Meursing Table plan.' do
        expect(additional_code_type.conformance_errors.keys).to include :CT7
      end
    end

    describe 'CT9' do
      let!(:additional_code_type)       { create :additional_code_type, :ern }
      let!(:export_refund_nomenclature) { create :export_refund_nomenclature, additional_code_type: additional_code_type.additional_code_type_id }

      before do
        additional_code_type.destroy
        additional_code_type.conformant?
      end

      specify 'The additional code type cannot be deleted if it is related with an Export refund code.' do
        expect(additional_code_type.conformance_errors.keys).to include :CT9
      end
    end

    describe 'CT10' do
      let!(:measure_type)               { create :measure_type }
      let!(:additional_code_type)       { create :additional_code_type }
      let!(:additional_code_type_measure_type) do
        create :additional_code_type_measure_type, measure_type_id: measure_type.measure_type_id,
                                                   additional_code_type_id: additional_code_type.additional_code_type_id
      end

      before do
        additional_code_type.destroy
        additional_code_type.conformant?
      end

      specify 'The additional code type cannot be deleted if it is related with a measure type.' do
        expect(additional_code_type.conformance_errors.keys).to include :CT10
      end
    end

    describe 'CT11' do
      pending 'The additional code type cannot be deleted if it is related with an Export Refund for Processed Agricultural Goods additional code.'
    end
  end

  describe '#export_refund_agricultural?' do
    let!(:ern_agricultural) { create :additional_code_type, :ern_agricultural }
    let!(:non_ern_agricultural) { create :additional_code_type, application_code: '1' }

    it 'returns true for ern_agricultural (code 4)' do
      expect(ern_agricultural).to be_export_refund_agricultural
    end

    it 'returns false for other' do
      expect(non_ern_agricultural).not_to be_export_refund_agricultural
    end
  end

  describe '#export_refund?' do
    let!(:ern) { create :additional_code_type, :ern }
    let!(:non_ern) { create :additional_code_type, application_code: '1' }

    it 'returns true for ern (code 0)' do
      expect(ern).to be_export_refund
    end

    it 'returns false for other' do
      expect(non_ern).not_to be_export_refund
    end
  end

  describe '#meursing?' do
    let!(:meursing) { create :additional_code_type, :meursing }
    let!(:non_meursing) { create :additional_code_type, application_code: '1' }

    it 'returns true for meursing (code 3)' do
      expect(meursing).to be_meursing
    end

    it 'returns false for other' do
      expect(non_meursing).not_to be_meursing
    end
  end
end
