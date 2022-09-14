RSpec.describe Api::V2::ValidityPeriodSerializer do
  subject(:serializable_hash) { described_class.new(presented).serializable_hash }

  let(:presented) do
    heading = create(
      :heading,
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
        type: :validity_period,
        attributes: {
          goods_nomenclature_item_id: '0101000000',
          producline_suffix: '80',
          validity_start_date: Date.parse('2021-01-01'),
          validity_end_date: nil,
          to_param: '0101',
          goods_nomenclature_class: 'Heading',
        },
      },
    }
  end

  describe '#serializable_hash' do
    it { is_expected.to eq(expected) }
  end
end
