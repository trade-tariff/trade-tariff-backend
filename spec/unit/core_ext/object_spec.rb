require 'core_ext/object'

RSpec.describe Object do
  describe '#tap!' do
    it 'returns self if block results in nil' do
      expect(
        'a'.tap! { nil },
      ).to eq 'a'
    end

    it 'returns block result if block does not result in nil' do
      expect(
        'a'.tap! { 'b' },
      ).to eq 'b'
    end
  end
end
