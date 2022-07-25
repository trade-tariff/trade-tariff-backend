require 'rails_helper'

RSpec.describe Search::GoodsNomenclatureIndex do
  subject(:instance) { described_class.new 'testnamespace' }

  it { is_expected.to have_attributes type: 'goods_nomenclature' }
  it { is_expected.to have_attributes name: 'testnamespace-goods_nomenclatures' }
  it { is_expected.to have_attributes model_class: GoodsNomenclature }
  it { is_expected.to have_attributes serializer: Search::GoodsNomenclatureSerializer }

  describe '#serialize_record' do
    subject { instance.serialize_record record }

    let(:record) { create :heading, :with_description }

    it { is_expected.to include 'goods_nomenclature_item_id' => record.goods_nomenclature_item_id }
  end

  describe '#dataset' do
    subject(:dataset) { described_class.new('testnamespace').dataset }

    it { is_expected.to be_a(Sequel::Postgres::Dataset) }
    it { expect(dataset.sql).to match(/(validity_start_date|validity_end_date)/) }
  end
end
