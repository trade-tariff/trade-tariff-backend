RSpec.describe Api::Admin::Headings::HeadingPresenter do
  let(:heading) { create(:heading, :with_descendants) }

  let(:counts) do
    {
      heading.goods_nomenclature_sid => 1,
      heading.descendants.first.goods_nomenclature_sid => 3,
      heading.descendants.last.goods_nomenclature_sid => 3,
    }
  end

  describe '.wrap' do
    subject(:wrapped) { described_class.wrap([heading], counts) }

    it { is_expected.to have_attributes length: 1 }
    it { is_expected.to all be_instance_of described_class }
    it { is_expected.to all have_attributes values: heading.values }
    it { is_expected.to all have_attributes search_references_count: 1 }
    it { expect(wrapped.first.commodities).to have_attributes length: 2 }
    it { expect(wrapped.first.commodities).to all have_attributes search_references_count: 3 }
  end

  describe '.new' do
    subject(:presented) { described_class.new(heading, counts) }

    it { is_expected.to be_a described_class }
    it { is_expected.to have_attributes values: heading.values }
    it { is_expected.to have_attributes search_references_count: 1 }
    it { expect(presented.commodities).to have_attributes length: 2 }
    it { expect(presented.commodities.first).to have_attributes pk: heading.descendants.first.pk }
    it { expect(presented.commodities.first).to have_attributes search_references_count: 3 }
  end
end
