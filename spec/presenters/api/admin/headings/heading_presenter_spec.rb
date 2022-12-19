RSpec.describe Api::Admin::Headings::HeadingPresenter do
  let(:heading) { create(:heading, :with_chapter, :non_declarable).reload }
  let(:commodity) { heading.commodities.first }

  let(:counts) do
    {
      heading.twelvedigit => 1,
      commodity.twelvedigit => 3,
    }
  end

  describe '.wrap' do
    subject(:wrapped) { described_class.wrap([heading], counts) }

    it { is_expected.to have_attributes length: 1 }
    it { is_expected.to all be_instance_of described_class }
    it { is_expected.to all have_attributes values: heading.values }
    it { is_expected.to all have_attributes search_references_count: 1 }
    it { expect(wrapped.first.commodities).to have_attributes length: 1 }
    it { expect(wrapped.first.commodities).to all have_attributes search_references_count: 3 }
  end

  describe '.new' do
    subject(:wrapped) { described_class.new(heading, counts) }

    it { is_expected.to be_instance_of described_class }
    it { is_expected.to have_attributes values: heading.values }
    it { is_expected.to have_attributes search_references_count: 1 }
    it { expect(wrapped.commodities).to have_attributes length: 1 }
    it { expect(wrapped.commodities.first).to have_attributes values: commodity.values }
    it { expect(wrapped.commodities.first).to have_attributes search_references_count: 3 }
  end
end
