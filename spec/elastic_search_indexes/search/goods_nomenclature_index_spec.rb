require 'rails_helper'

RSpec.describe Search::GoodsNomenclatureIndex do
  subject(:instance) { described_class.new 'testnamespace' }

  it { is_expected.to have_attributes type: 'goods_nomenclature' }
  it { is_expected.to have_attributes name: 'testnamespace-goods_nomenclatures-uk' }
  it { is_expected.to have_attributes name_without_namespace: 'GoodsNomenclatureIndex' }
  it { is_expected.to have_attributes model_class: GoodsNomenclature }
end
