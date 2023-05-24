RSpec.describe Api::V2::Measures::MeasurementUnitQualifierSerializer do
  describe '#serializable_hash' do
    subject(:serializable_hash) { described_class.new(serializable).serializable_hash }

    let(:serializable) { create(:measurement_unit_qualifier, :with_description) }

    let(:expected_pattern) do
      {
        data: {
          id: serializable.pk,
          type: :measurement_unit_qualifier,
          attributes: {
            description: serializable.description,
            formatted_description: serializable.formatted_measurement_unit_qualifier,
          },
        },
      }
    end

    it { is_expected.to include(expected_pattern) }
  end
end
