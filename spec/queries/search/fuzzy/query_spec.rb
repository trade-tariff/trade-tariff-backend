RSpec.describe Search::Fuzzy::Query do
  subject(:query_instance) { described_class.new('test', Time.zone.today, Search::CommodityIndex.new) }

  describe '#match_type' do
    it 'derives match type from class name' do
      expect(query_instance.match_type).to eq(:_match)
    end
  end

  context 'with a subclass' do
    it 'derives match type from the subclass name' do
      subclass = Class.new(described_class)
      stub_const('Search::Fuzzy::ExampleQuery', subclass)

      instance = subclass.new('test', Time.zone.today, Search::CommodityIndex.new)
      expect(instance.match_type).to eq(:example_match)
    end
  end
end
