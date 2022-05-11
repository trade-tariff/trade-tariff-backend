RSpec.describe Admin::QueryAllCommodities do
  subject(:service) { described_class }

  describe '#call' do
    before do
      create(:commodity,
             :with_description,
             :with_chapter,
             :with_heading,
             :with_indent,
             :with_children,
             :declarable)
    end

    it 'returns the list of all commodities' do
      expect(service.call('2022-01-01').count).to eq(1)
    end
  end
end
