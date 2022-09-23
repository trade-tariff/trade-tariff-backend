require 'rails_helper'

RSpec.describe Search::GoodsNomenclatureIndex do
  subject(:index) { described_class.new('testnamespace') }

  it { is_expected.to have_attributes type: 'goods_nomenclature' }
  it { is_expected.to have_attributes name: 'testnamespace-goods_nomenclatures-uk' }
  it { is_expected.to have_attributes model_class: GoodsNomenclature }
  it { is_expected.to have_attributes serializer: Search::GoodsNomenclatureSerializer }

  describe '#serialize_record' do
    subject { index.serialize_record(record) }

    let(:record) { create :heading, :with_description }

    it { is_expected.to include 'goods_nomenclature_item_id' => record.goods_nomenclature_item_id }
  end

  describe '#dataset' do
    subject(:dataset) { described_class.new('testnamespace').dataset }

    before do
      create(:chapter, goods_nomenclature_item_id: '0100000000')                # chapter          -> included
      create(:heading, :grouping, goods_nomenclature_item_id: '0101000000')     # grouping heading -> not included
      create(:heading, :non_grouping, goods_nomenclature_item_id: '0101000000') # heading          -> included
      create(:commodity, goods_nomenclature_item_id: '0101210000')              # commodity        -> included
      create(:commodity, :grouping, goods_nomenclature_item_id: '0101210000')   # commodity        -> included
    end

    let(:expected_goods_nomenclatures) do
      [
        %w[0100000000 80],
        %w[0101000000 80],
        %w[0101210000 10],
        %w[0101210000 80],
      ]
    end

    it { is_expected.to be_a(Sequel::Postgres::Dataset) }

    it 'uses the time machine' do
      expect(dataset.sql).to match(/(validity_start_date|validity_end_date)/)
    end

    it 'returns the expected goods nomenclatures' do
      expect(dataset.all.pluck(:goods_nomenclature_item_id, :producline_suffix)).to eq(expected_goods_nomenclatures)
    end
  end
end
