require 'rails_helper'

RSpec.describe ChiefCdsGuidance do
  describe '#guidance_for' do
    subject(:guidance) { described_class.load_default.guidance_for(document_code) }

    context 'when the document code exists in the guidance file' do
      let(:document_code) { 'A001' }

      it 'returns the correct guidance' do
        expected_guidance = {
          'code' => 'A001',
          'direction' => 'I',
          'description' => "Certificate of authenticity fresh 'EMPEROR' table grapes. EC regulation 1832/2002 amending Annex 1 to Council regulation 2658/87 on the tariff and statistical nomenclature and on the Common Customs Tariff.",
          'guidance_cds' => "- Enter the reference number of the Certificate of authenticity for fresh 'EMPEROR' table grapes.\n\n- Where a sequentially numbered range of certificates covers the goods, enter the lowest to the highest reference numbers of the certificates concerned, e.g. document code + 0054037-0054047: status code.\n\n- Where certificates are not sequentially numbered, enter the reference number of each certificate concerned.\n\n- Use the following [document status code](https://www.gov.uk/government/publications/uk-trade-tariff-document-status-codes-for-harmonised-declarations/uk-trade-tariff-document-status-codes-for-harmonised-declarations): AC",
          'guidance_chief' => "- Use status code AC.\n\n",
          'status_codes_cds' => %w[
            AC
          ],
          'used' => 'Yes',
        }

        expect(guidance).to eq(expected_guidance)
      end
    end

    context 'when the document code does not exist in the guidance file' do
      let(:document_code) { 'foo' }

      it { is_expected.to be_nil }
    end
  end
end
