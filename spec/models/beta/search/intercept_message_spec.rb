RSpec.describe Beta::Search::InterceptMessage do
  describe '.build' do
    subject(:intercept_message) { described_class.build(search_query) }

    context 'when the query corresponds to an existing intercept message' do
      let(:search_query) { 'plasti' }

      it { is_expected.to be_a(described_class) }
      it { expect(intercept_message.id).to eq('9798b947790cd77dec021f882e7b3e29') }
      it { expect(intercept_message).to respond_to(:term) }
      it { expect(intercept_message).to respond_to(:message) }
    end

    context 'when the query does not correspond to an intercept message' do
      let(:search_query) { 'foo' }

      it { is_expected.to be_nil }
    end
  end

  describe '#formatted_message' do
    context 'when there are a mixture of different goods nomenclature to generate links for' do
      subject(:formatted_message) { build(:intercept_message, :with_mixture_of_goods_nomenclature_to_transform).formatted_message }

      let(:expected_message) do
        '(chapter 1)[/chapters/01], (heading 0101)[/headings/0101], (subheading 012012)[/subheadings/0120120000-80] and (commodity 0702000007)[/commodities/0702000007].'
      end

      it { is_expected.to eq(expected_message) }
    end

    context 'when there are chapters to generate links for' do
      subject(:formatted_message) { build(:intercept_message, :with_chapters_to_transform).formatted_message }

      let(:expected_message) do
        'This should point to (ChaPter 99)[/chapters/99] and (chapters 32)[/chapters/32] and (chapters 1)[/chapters/01] but not chapter 19812321 but for (chapter 9)[/chapters/09].'
      end

      it { is_expected.to eq(expected_message) }
    end

    context 'when there are headings to generate links for' do
      subject(:formatted_message) { build(:intercept_message, :with_headings_to_transform).formatted_message }

      let(:expected_message) do
        'This should point to (hEadIngs 0101)[/headings/0101] and (heading 0102)[/headings/0102] but not heading 2 or heading 012012 but for (heading 0105)[/headings/0105].'
      end

      it { is_expected.to eq(expected_message) }
    end

    context 'when there are subheadings to generate links for' do
      subject(:formatted_message) { build(:intercept_message, :with_subheadings_to_transform).formatted_message }

      let(:expected_message) do
        'This should point to (subheadiNg 010511)[/subheadings/0105110000-80] and (subheadings 01051191)[/subheadings/0105119100-80] and never change subheading 1231 or subheading 1231312312 but for (subheading 010512)[/subheadings/0105120000-80].'
      end

      it { is_expected.to eq(expected_message) }
    end

    context 'when there are commodities to generate links for' do
      subject(:formatted_message) { build(:intercept_message, :with_commodities_to_transform).formatted_message }

      let(:expected_message) do
        'This should point to (coMmodities 0105110000)[/commodities/0105110000] and cOmmodity 01051191 and never change commodity 1 or commodity 13112313123123 but for (commodity 0101210001)[/commodities/0101210001].'
      end

      it { is_expected.to eq(expected_message) }
    end

    context 'when there is no corresponding message' do
      subject(:formatted_message) { build(:intercept_message, :without_message).formatted_message }

      let(:expected_message) { '' }

      it { is_expected.to eq(expected_message) }
    end
  end
end
