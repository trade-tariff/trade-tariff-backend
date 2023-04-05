RSpec.describe Api::Admin::QuotaOrderNumbers::MeasurementUnitSerializer do
  describe '#serializable_hash' do
    subject(:serialized) { described_class.new(serializable).serializable_hash }

    let(:serializable) { create(:measurement_unit, :with_description) }

    let(:expected) do
      {
        data: {
          id: serializable.measurement_unit_code,
          type: eq(:measurement_unit),
          attributes: {
            description: be_a(String),
            measurement_unit_code: be_a(String),
            abbreviation: be_a(String),
          },
        },
      }
    end

    it { is_expected.to include_json(expected) }
  end
end
