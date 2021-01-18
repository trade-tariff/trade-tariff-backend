require 'rails_helper'

describe BaseRegulation do
  describe 'validations' do
    # ROIMB1
    it { is_expected.to validate_uniqueness.of(%i[base_regulation_id base_regulation_role]) }
    # ROIMB3
    it { is_expected.to validate_validity_dates }

    context 'ROIMB4' do
      let(:base_regulation) do
        build(:base_regulation, regulation_group_id: regulation_group_id)
      end

      before { base_regulation.conformant? }

      describe 'valid' do
        let(:regulation_group_id) { create(:regulation_group).regulation_group_id }

        it { expect(base_regulation.conformance_errors).to be_empty }
      end

      describe 'invalid' do
        let(:regulation_group_id) { 'ACC' }

        it {
          expect(base_regulation.conformance_errors).to have_key(:ROIMB4)
        }
      end
    end
  end
end
