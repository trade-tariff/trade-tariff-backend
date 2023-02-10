RSpec.describe Api::V2::ValidityPeriodSerializer do
  subject(:serializable_hash) { described_class.new(presented).serializable_hash }

  let(:presented) do
    heading = create(
      :heading,
      :with_deriving_goods_nomenclatures,
      goods_nomenclature_item_id: '0101000000',
      validity_start_date: '2021-01-01',
      validity_end_date: nil,
    )

    Api::V2::ValidityPeriodPresenter.new(heading)
  end

  let(:expected) do
    {
      data: {
        id: 'd259221ad1eee90454351c0fa0404179',
        type: eq(:validity_period),
        attributes: {
          goods_nomenclature_item_id: '0101000000',
          producline_suffix: '80',
          validity_start_date: '2021-01-01T00:00:00.000Z',
          validity_end_date: nil,
          description: '',
          formatted_description: '',
          to_param: '0101',
        },
        relationships: { deriving_goods_nomenclatures: { data: [{ id: match(/\d+/), type: eq(:commodity) }] } },
      },
    }
  end

  describe '#serializable_hash' do
    it { is_expected.to include_json(expected) }
  end
end
