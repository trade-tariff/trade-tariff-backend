require 'rails_helper'

RSpec.describe ChiefCdsGuidance do
  describe '#cds_guidance_for' do
    shared_examples_for 'a correct cds guidance result' do |document_code, expected_guidance|
      subject(:cds_guidance_for) { described_class.load_default.cds_guidance_for(document_code) }

      it { is_expected.to eq(expected_guidance) }
    end

    it_behaves_like 'a correct cds guidance result', '9RCP', "- Enter the RPA recipe number.\n\n- No document status code is required."
    it_behaves_like 'a correct cds guidance result', 'foo', 'No additional information is available.'
    it_behaves_like 'a correct cds guidance result', '', nil
    it_behaves_like 'a correct cds guidance result', nil, nil
  end

  describe '#chief_guidance_for' do
    shared_examples_for 'a correct cds guidance result' do |document_code, expected_guidance|
      subject(:chief_guidance_for) { described_class.load_default.chief_guidance_for(document_code) }

      it { is_expected.to eq(expected_guidance) }
    end

    it_behaves_like 'a correct cds guidance result', 'A001', "- Use status code <abbr title='Document attached for certification by customs'>AC</abbr>."
    it_behaves_like 'a correct cds guidance result', 'A007', 'No additional information is available.'
    it_behaves_like 'a correct cds guidance result', 'foo', 'No additional information is available.'
    it_behaves_like 'a correct cds guidance result', '', nil
    it_behaves_like 'a correct cds guidance result', nil, nil
  end
end
