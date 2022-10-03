RSpec.describe Api::V2::GeographicalAreaTreeSerializer do
  describe '#serializable_hash' do
    subject(:serializable_hash) { described_class.new(serializable).serializable_hash }

    let(:serializable) { create(:geographical_area, geographical_area_id: 'IT', hjid: '12312') }

    let(:expected) do
      {
        data: {
          id: 'IT',
          type: eq(:geographical_area),
          attributes: {
            description: be_present,
            hjid: 12_312,
            geographical_area_id: 'IT',
          },
        },
      }
    end

    it { is_expected.to include_json(expected) }
  end
end
