RSpec.describe TariffKnowledge::GraphQuery do
  describe '.call' do
    it 'returns plain validation failures without HTTP presentation fields' do
      result = described_class.call(
        subjects: [],
        traversals: [
          {
            edge_type: 'not_an_edge',
            direction: 'sideways',
          },
        ],
      )

      expect(result).to include(
        errors: include(
          include(
            pointer: '/data/attributes/traversals/0/edge_type',
            detail: "edge_type must be one of #{TariffKnowledge::Edge::TYPES.join(', ')}",
          ),
          include(
            pointer: '/data/attributes/traversals/0/direction',
            detail: 'direction must be incoming or outgoing',
          ),
        ),
      )
      expect(result[:errors].first).not_to include(:status, :title, :source)
    end
  end
end
