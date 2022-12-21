RSpec.describe Beta::Search::InterceptMessage do
  describe '.build' do
    shared_examples 'an intercept message query with a corresponding message' do |search_query|
      subject(:intercept_message) { described_class.build(search_query) }

      it { is_expected.to be_a(described_class) }
      it { expect(intercept_message.id).to be_present }
      it { expect(intercept_message).to respond_to(:term) }
      it { expect(intercept_message).to respond_to(:message) }
    end

    it_behaves_like 'an intercept message query with a corresponding message', 'plasti'
    it_behaves_like 'an intercept message query with a corresponding message', "new  #{160.chr('UTF-8')}  Zealand"
    it_behaves_like 'an intercept message query with a corresponding message', 'apparel - clothing - worn, in bulk packings'

    context 'when the query does not correspond to an intercept message' do
      subject(:intercept_message) { described_class.build('foo') }

      it { is_expected.to be_nil }
    end
  end

  describe '.all_references' do
    subject(:all_references) { described_class.all_references }

    it 'merges reference intercept terms to the same goods nomenclature' do
      expect(all_references['9031800000'])
        .to eq('accelerometer bruel kjaer eddy current eddyfi ectane fitbit rotary encoder')
    end
  end

  describe '#generate_references_and_formatted_message!' do
    subject(:intercept_message) { build(:intercept_message, trait) }

    before do
      intercept_message.generate_references_and_formatted_message!
    end

    context 'when there are a mixture of different goods nomenclature to generate links for' do
      let(:trait) { :with_mixture_of_goods_nomenclature_to_transform }

      let(:expected_message) do
        '[chapter 1](/chapters/01), [heading 0101](/headings/0101), [subheading 012012](/subheadings/0120120000-80) and [commodity 0702000007](/commodities/0702000007).'
      end

      let(:expected_references) do
        {
          '0120120000' => 'foo',
          '0702000007' => 'foo',
        }
      end

      it { expect(intercept_message.formatted_message).to eq(expected_message) }
      it { expect(intercept_message.references).to eq(expected_references) }
    end

    context 'when there are chapters to generate links for' do
      let(:trait) { :with_chapters_to_transform }

      let(:expected_message) do
        'This should point to [ChaPter 99](/chapters/99) and [chapters 32](/chapters/32) and [chapters 1](/chapters/01) but not chapter 19812321 but for [chapter 9](/chapters/09).'
      end

      let(:expected_references) { {} }

      it { expect(intercept_message.formatted_message).to eq(expected_message) }
      it { expect(intercept_message.references).to eq(expected_references) }
    end

    context 'when there are headings to generate links for' do
      let(:trait) { :with_headings_to_transform }

      let(:expected_message) do
        'This should point to [hEadIngs 0101](/headings/0101) and [heading 0102](/headings/0102) but not heading 2 or heading 012012 but for [heading 0105](/headings/0105) / [9503](/headings/9503).'
      end

      let(:expected_references) { {} }

      it { expect(intercept_message.formatted_message).to eq(expected_message) }
      it { expect(intercept_message.references).to eq(expected_references) }
    end

    context 'when there are subheadings to generate links for' do
      let(:trait) { :with_subheadings_to_transform }

      let(:expected_message) do
        'This should point to [subheadiNg 010511](/subheadings/0105110000-80) and [subheadings 01051191](/subheadings/0105119100-80) and never change subheading 1231312312 but for [subheading 010512](/subheadings/0105120000-80).'
      end

      let(:expected_references) do
        {
          '0105110000' => 'foo',
          '0105119100' => 'foo',
          '0105120000' => 'foo',
        }
      end

      it { expect(intercept_message.formatted_message).to eq(expected_message) }
      it { expect(intercept_message.references).to eq(expected_references) }
    end

    context 'when there are commodities to generate links for' do
      let(:trait) { :with_commodities_to_transform }

      let(:expected_message) do
        'This should point to [coMmodities 0105110000](/commodities/0105110000) and cOmmodity 01051191 and never change commodity 1 or commodity 13112313123123 but for [commodity 0101210001](/commodities/0101210001).'
      end

      let(:expected_references) do
        {
          '0101210001' => 'foo',
          '0105110000' => 'foo',
        }
      end

      it { expect(intercept_message.formatted_message).to eq(expected_message) }
      it { expect(intercept_message.references).to eq(expected_references) }
    end

    context 'when there is no corresponding message' do
      let(:trait) { :without_message }

      let(:expected_message) { '' }
      let(:expected_references) { {} }

      it { expect(intercept_message.formatted_message).to eq(expected_message) }
      it { expect(intercept_message.references).to eq(expected_references) }
    end

    context 'when there are sections to generate links for' do
      let(:trait) { :with_section_to_transform }

      let(:expected_message) do
        'Based on your search term, we believe you are looking for [section XV](/sections/15), [section position 14](/sections/14) and [section code III](/sections/3) depending on the constituent material.'
      end

      let(:expected_references) { {} }

      it { expect(intercept_message.formatted_message).to eq(expected_message) }
      it { expect(intercept_message.references).to eq(expected_references) }
    end
  end
end
