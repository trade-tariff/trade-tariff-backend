require 'rails_helper'

RSpec.describe ChiefCdsGuidance do
  subject(:chief_cds_guidance) { described_class.new({}) }

  it { is_expected.to respond_to(:guidance_last_updated_at) }
  it { is_expected.to respond_to(:guidance) }

  describe '.load_latest' do
    subject(:load_latest) { described_class.load_latest }

    include_context 'with a stubbed chief cds guidance s3 bucket'

    it { is_expected.to be_a(described_class) }
  end

  describe '.load_fallback' do
    subject(:load_fallback) { described_class.load_fallback }

    it { is_expected.to be_a(described_class) }
  end

  describe '#cds_guidance_for' do
    shared_examples_for 'a correct cds guidance result' do |document_code, expected_guidance|
      context 'when loading default guidance' do
        subject(:cds_guidance_for) { described_class.load_fallback.cds_guidance_for(document_code) }

        it { is_expected.to eq(expected_guidance) }
      end

      context 'when loading the latest guidance' do
        subject(:cds_guidance_for) { described_class.load_latest.cds_guidance_for(document_code) }

        include_context 'with a stubbed chief cds guidance s3 bucket'

        it { is_expected.to eq(expected_guidance) }
      end
    end

    it_behaves_like 'a correct cds guidance result', '9RCP', "- Enter the RPA recipe number.\n\n- No document status code is required."
    it_behaves_like 'a correct cds guidance result', 'foo', 'No additional information is available.'
    it_behaves_like 'a correct cds guidance result', '', nil
    it_behaves_like 'a correct cds guidance result', nil, nil
  end

  describe '#chief_guidance_for' do
    shared_examples_for 'a correct chief guidance result' do |document_code, expected_guidance|
      context 'when loading default guidance' do
        subject(:chief_guidance_for) { described_class.load_fallback.chief_guidance_for(document_code) }

        it { is_expected.to eq(expected_guidance) }
      end

      context 'when loading the latest guidance' do
        subject(:chief_guidance_for) { described_class.load_latest.chief_guidance_for(document_code) }

        include_context 'with a stubbed chief cds guidance s3 bucket'

        it { is_expected.to eq(expected_guidance) }
      end
    end

    it_behaves_like 'a correct chief guidance result', 'A001', "- Use status code <abbr title='Document attached for certification by customs'>AC</abbr>."
    it_behaves_like 'a correct chief guidance result', 'A007', 'This document code is available on CDS only.'
    it_behaves_like 'a correct chief guidance result', 'foo', 'No additional information is available.'
    it_behaves_like 'a correct chief guidance result', '', nil
    it_behaves_like 'a correct chief guidance result', nil, nil
  end
end
