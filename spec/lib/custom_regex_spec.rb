RSpec.describe CustomRegex do
  describe '#cas_number_regex' do
    subject(:custom_regex) { Class.new { include CustomRegex }.new.cas_number_regex }

    context 'when the input is a CAS number' do
      let(:input) { '10310-21-1' }

      it { is_expected.to match(input) }
      it { expect(custom_regex.match(input)[1]).to eq('10310-21-1') }
    end

    context 'when the input is a CAS number with leading "cas"' do
      let(:input) { 'cas 10310-21-1' }

      it { is_expected.to match(input) }
      it { expect(custom_regex.match(input)[1]).to eq('10310-21-1') }
    end

    context 'when the input is a CAS number with leading "cas" and other text' do
      let(:input) { 'cas rn 10310-21-1' }

      it { is_expected.to match(input) }
      it { expect(custom_regex.match(input)[1]).to eq('10310-21-1') }
    end

    context 'when the input is a CAS number with leading "cas" and other text before and after' do
      let(:input) { 'cas rn blah 10310-21-1foobar biz baz   other text' }

      it { is_expected.to match(input) }
      it { expect(custom_regex.match(input)[1]).to eq('10310-21-1') }
    end

    context 'when the input is a CAS number with leading "cas" and other text before and after, with additional digits after the CAS number' do
      let(:input) { 'cas rn blah 10310-21-1684984654687foobar biz baz   other text' }

      it { is_expected.to match(input) }
      it { expect(custom_regex.match(input)[1]).to eq('10310-21-1') }
    end

    context 'when the input is a CAS number with letters' do
      let(:input) { '10310-21-A' }

      it { is_expected.not_to match(input) }
    end
  end

  describe '#cus_number_regex' do
    subject(:custom_regex) { Class.new { include CustomRegex }.new.cus_number_regex }

    context 'when the input is a CUS number' do
      let(:input) { '1234567-1' }

      it { is_expected.to match(input) }
    end

    context 'when the input is not a CUS number' do
      let(:input) { '1234567-12' }

      it { is_expected.not_to match(input) }
    end
  end
end
