RSpec.describe Hashie::TariffMash do
  describe '#to_a' do
    subject(:mash) { described_class.new(foo: :bar) }

    # NOTE: The to_a method is used in internal comparisons in matchers so to verify the resulting
    #       Array I need to directly call the == method. Ideally we'd not have to override this method/stop being clever
    #       in using Mashie in place of the presenter pattern.
    it { expect(mash.to_a == [{ 'foo' => :bar }]).to eq(true) }
  end
end
