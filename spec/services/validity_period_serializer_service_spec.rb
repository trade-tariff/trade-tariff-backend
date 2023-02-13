RSpec.describe ValidityPeriodSerializerService do
  describe '#call' do
    context 'when the goods nomenclature is a heading' do
      subject(:call) { described_class.new(params).call }

      before do
        create(
          :heading,
          :with_deriving_goods_nomenclatures,
          goods_nomenclature_item_id: '0101000000',
          validity_start_date: Date.new(2023, 1, 1),
          validity_end_date: Date.new(2023, 2, 1),
        )
        create(
          :heading,
          :with_deriving_goods_nomenclatures,
          goods_nomenclature_item_id: '0101000000',
          validity_start_date: Date.new(2023, 1, 2),
          validity_end_date: Date.new(2023, 2, 1),
        )
      end

      let(:params) { { heading_id: '0101' } }

      it 'returns serialized validity periods that are sorted by validity start date' do
        validity_start_dates = call[:data].map { |period| period[:attributes][:validity_start_date] }
        expect(validity_start_dates).to eq(%w[2023-01-02 2023-01-01])
      end
    end

    context 'when the goods nomenclature is a subheading' do
      subject(:call) { described_class.new(params).call }

      before do
        create(
          :commodity,
          :with_deriving_goods_nomenclatures,
          goods_nomenclature_item_id: '0101210000',
          producline_suffix: '80',
          validity_start_date: Date.new(2023, 1, 1),
          validity_end_date: Date.new(2023, 2, 1),
        )
        create(
          :commodity,
          :with_deriving_goods_nomenclatures,
          goods_nomenclature_item_id: '0101210000',
          producline_suffix: '80',
          validity_start_date: Date.new(2023, 1, 2),
          validity_end_date: Date.new(2023, 2, 1),
        )
      end

      let(:params) { { subheading_id: '0101210000-80' } }

      it 'returns serialized validity periods that are sorted by validity start date' do
        validity_start_dates = call[:data].map { |period| period[:attributes][:validity_start_date] }
        expect(validity_start_dates).to eq(%w[2023-01-02 2023-01-01])
      end
    end

    context 'when the goods nomenclature is a commodity' do
      subject(:call) { described_class.new(params).call }

      before do
        create(
          :commodity,
          :with_deriving_goods_nomenclatures,
          goods_nomenclature_item_id: '0101210000',
          producline_suffix: '80',
          validity_start_date: Date.new(2023, 1, 1),
          validity_end_date: Date.new(2023, 2, 1),
        )
        create(
          :commodity,
          :with_deriving_goods_nomenclatures,
          goods_nomenclature_item_id: '0101210000',
          producline_suffix: '80',
          validity_start_date: Date.new(2023, 1, 2),
          validity_end_date: Date.new(2023, 2, 1),
        )
      end

      let(:params) { { commodity_id: '0101210000' } }

      it 'returns serialized validity periods that are sorted by validity start date' do
        validity_start_dates = call[:data].map { |period| period[:attributes][:validity_start_date] }
        expect(validity_start_dates).to eq(%w[2023-01-02 2023-01-01])
      end
    end

    context 'when the goods nomenclature is not found' do
      subject(:call) { described_class.new(params).call }

      let(:params) { { heading_id: '0101' } }

      it 'returns an empty array' do
        expect(call[:data]).to eq([])
      end
    end
  end
end
