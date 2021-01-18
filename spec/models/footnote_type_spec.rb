require 'rails_helper'

describe FootnoteType do
  describe 'validations' do
    # FOT1: footnote_type_id
    it { is_expected.to validate_uniqueness.of :footnote_type_id }
    # FOT3: validity_dates
    it { is_expected.to validate_validity_dates }
    # FOT2 The footnote type cannot be deleted if it is used in a footnote.

    describe 'FOT2' do
      let!(:footnote_type) { create :footnote_type }
      let!(:footnote)      { create :footnote, footnote_type_id: footnote_type.footnote_type_id }

      before do
        footnote_type.destroy
        footnote_type.conformant?
      end

      it 'does not allow footnote_type deletion' do
        expect(footnote_type.conformance_errors.keys).to include :FOT2
      end
    end
  end
end
