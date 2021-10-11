RSpec.describe Api::V2::RulesOfOrigin::ProofSerializer do
  subject(:serializable) { described_class.new(proof).serializable_hash }

  let(:scheme_set) { instance_double RulesOfOrigin::SchemeSet, proof_urls: urls }
  let(:scheme) { build :rules_of_origin_scheme, scheme_set: scheme_set }
  let(:proof) { build :rules_of_origin_proof, scheme: scheme }
  let(:urls) { { 'origin-declaration' => 'https://www.gov.uk/' } }

  let :expected do
    {
      data: {
        id: proof.id,
        type: :rules_of_origin_proof,
        attributes: {
          summary: proof.summary,
          subtext: proof.subtext,
          url: proof.url,
        },
      },
    }
  end

  describe '#serializable_hash' do
    it 'matches the expected hash' do
      expect(serializable).to eql expected
    end
  end
end
