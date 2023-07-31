RSpec.describe Api::V2::AdditionalCodes::AdditionalCodeSerializer do
  describe '#serializable_hash' do
    subject(:serializable_hash) { described_class.new(serializable).serializable_hash }

    let(:serializable) do
      additional_code = create(:additional_code, :with_description)

      Api::V2::AdditionalCodeSearch::AdditionalCodePresenter.new(additional_code, goods_nomenclatures)
    end

    let(:expected) do
      {
        data: {
          id: be_present,
          type: eq(:additional_code),
          attributes: {
            additional_code_type_id: be_present,
            additional_code: be_present,
            code: be_present,
            description: be_present,
            formatted_description: be_present,
          },
          relationships: {
            goods_nomenclatures: {
              data: [
                { id: be_present, type: eq(:chapter) },
                { id: be_present, type: eq(:heading) },
                { id: be_present, type: eq(:subheading) },
                { id: be_present, type: eq(:commodity) },
              ],
            },
          },
        },
      }
    end

    let(:goods_nomenclatures) do
      [
        create(:chapter),
        create(:heading),
        create(:subheading),
        create(:commodity),
      ]
    end

    it { is_expected.to include_json(expected) }
  end
end
