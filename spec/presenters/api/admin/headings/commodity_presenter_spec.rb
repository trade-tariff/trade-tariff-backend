RSpec.describe Api::Admin::Headings::CommodityPresenter do
  let(:commodity) { create :commodity }

  describe '.wrap' do
    subject { described_class.wrap([commodity], { commodity.goods_nomenclature_sid => 3 }) }

    it { is_expected.to have_attributes length: 1 }
    it { is_expected.to all be_instance_of described_class }
    it { is_expected.to all have_attributes values: commodity.values }
    it { is_expected.to all have_attributes search_references_count: 3 }

    context 'with nil count' do
      subject { described_class.wrap([commodity], { commodity.goods_nomenclature_sid => nil }) }

      it { is_expected.to all have_attributes search_references_count: nil }
    end

    context 'without count' do
      subject { described_class.wrap([commodity], {}) }

      it { is_expected.to all have_attributes search_references_count: 0 }
    end
  end

  describe '.new' do
    subject { described_class.new(commodity, 3) }

    it { is_expected.to be_instance_of described_class }
    it { is_expected.to have_attributes values: commodity.values }
    it { is_expected.to have_attributes search_references_count: 3 }
  end
end
