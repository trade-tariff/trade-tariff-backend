RSpec.describe SearchNegationService do
  describe '#call' do
    shared_examples 'a service which removes negation' do |text, expected|
      it 'removes negation' do
        expect(described_class.new(text).call).to eq(expected)
      end
    end

    it_behaves_like 'a service which removes negation', 'some text, not other text', 'some text'
    it_behaves_like 'a service which removes negation', 'some text, neither other text', 'some text'
    it_behaves_like 'a service which removes negation', 'some text, other than other text', 'some text'
    it_behaves_like 'a service which removes negation', 'some text, excluding other text', 'some text'
    it_behaves_like 'a service which removes negation', 'some text, except other text', 'some text'
    it_behaves_like 'a service which removes negation', "shorts (other than swimwear) - women's or girl's knitted or crocheted", "shorts  - women's or girl's knitted or crocheted"
    it_behaves_like 'a service which removes negation', 'fabric (textile) woven - vegetable textile fibres - (other than cotton and flax)', 'fabric (textile) woven - vegetable textile fibres -'
    it_behaves_like 'a service which removes negation', 'fabrics (textile) other than knitted, crocheted or woven - felt', 'fabrics (textile)- felt'
    it_behaves_like 'a service which removes negation', "I have a\u00A0non-breaking space", 'I have a non-breaking space'
    it_behaves_like 'a service which removes negation', 'some text', 'some text'
    it_behaves_like 'a service which removes negation', nil, ''
    it_behaves_like 'a service which removes negation', '', ''
    it_behaves_like 'a service which removes negation', "some text, not other text.\nsome text, other than other text.", "some text\nsome text"
  end
end
