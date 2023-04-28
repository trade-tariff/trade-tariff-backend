RSpec.describe Api::V2::GeographicalAreaSerializer do
  describe '#serializable_hash' do
    subject(:serializable_hash) { described_class.new(serializable).serializable_hash }

    let(:serializable) { create(:geographical_area, :with_description, geographical_area_id: 'IT') }

    let(:expected) do
      {
        data: {
          id: 'IT',
          type: eq(:geographical_area),
          attributes: {
            description: be_present,
            id: 'IT',
            geographical_area_id: 'IT',
            geographical_area_sid: serializable.geographical_area_sid,
          },
        },
      }
    end

    it { is_expected.to include_json(expected) }
  end
end
