require 'rails_helper'

RSpec.describe Search::GoodsNomenclatureIndex do
  subject(:index) { described_class.new('testnamespace') }

  it { is_expected.to have_attributes type: 'goods_nomenclature' }
  it { is_expected.to have_attributes name: 'testnamespace-goods_nomenclatures' }
  it { is_expected.to have_attributes model_class: GoodsNomenclature }
  it { is_expected.to have_attributes serializer: Search::GoodsNomenclatureSerializer }

  describe '#serialize_record' do
    subject { index.serialize_record(record) }

    let(:record) { create :heading, :with_description }

    it { is_expected.to include 'goods_nomenclature_item_id' => record.goods_nomenclature_item_id }
  end

  describe '#dataset' do
    subject(:dataset) { described_class.new('testnamespace').dataset }

    it { is_expected.to be_a(Sequel::Postgres::Dataset) }

    it 'uses the time machine' do
      expect(dataset.sql).to match(/(validity_start_date|validity_end_date)/)
    end

    it 'excludes headings that are grouping' do
      expect(dataset.sql).to include("AND NOT (goods_nomenclatures.goods_nomenclature_item_id LIKE '____000000' AND producline_suffix != '80')")
    end
  end
end
