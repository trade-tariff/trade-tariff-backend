RSpec.describe Api::V2::RulesOfOrigin::ProofSerializer do
  subject(:serializable) { described_class.new(proof).serializable_hash }

  before do
    allow(scheme_set).to receive(:read_referenced_file)
                         .and_return('proof content')
  end

  let(:scheme_set) { instance_double RulesOfOrigin::SchemeSet }
  let(:scheme) { build :rules_of_origin_scheme, scheme_set: scheme_set }
  let(:proof) { build :rules_of_origin_proof, scheme: scheme }

  let :expected do
    {
      data: {
        id: proof.id,
        type: :rules_of_origin_proof,
        attributes: {
          summary: proof.summary,
          content: proof.content,
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
