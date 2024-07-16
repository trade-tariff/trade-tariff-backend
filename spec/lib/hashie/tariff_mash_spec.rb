RSpec.describe Hashie::TariffMash do
  subject(:mash) { described_class.new(foo: :bar) }

  describe '#to_a' do
    # NOTE: The to_a method is used in internal comparisons in matchers so to verify the resulting
    #       Array I need to directly call the == method. Ideally we'd not have to override this method/stop being clever
    #       in using Mashie in place of the presenter pattern.
    it { expect(mash.to_a == [{ 'foo' => :bar }]).to be(true) }
  end

  describe '#respond_to?' do
    context 'when passed :map' do
      let(:respond_to_method) { :map }

      it { expect(mash.respond_to?(respond_to_method)).to be(false) }
    end

    context 'when passed "map"' do
      let(:respond_to_method) { 'map' }

      it { expect(mash.respond_to?(respond_to_method)).to be(false) }
    end

    context 'when passed something Mashie implements' do
      let(:respond_to_method) { 'foo' }

      it { expect(mash.respond_to?(respond_to_method)).to be(true) }
    end

    context 'when passed something Mashie does not implement' do
      let(:respond_to_method) { 'bar' }

      it { expect(mash.respond_to?(respond_to_method)).to be(false) }
    end
  end
end
