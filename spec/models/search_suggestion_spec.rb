RSpec.describe SearchSuggestion do
  describe '#goods_nomenclature' do
    subject(:goods_nomenclature) do
      create(
        :search_suggestion,
        :goods_nomenclature,
        goods_nomenclature: create(:heading),
      ).goods_nomenclature
    end

    it { is_expected.to be_a(Heading) }
  end

  describe '.fuzzy_search' do
    subject(:fuzzy_search) { described_class.fuzzy_search(query) }

    context 'when the query is a similar but mispelled word' do
      let(:query) { 'alu' }

      before do
        create(:search_suggestion, :search_reference, value: 'aluminium wire')
        create(:search_suggestion, :search_reference, value: 'nuts, aluminium')
        create(:search_suggestion, :search_reference, value: 'bars - aluminium')
        create(:search_suggestion, :search_reference, value: 'alu')
        create(:search_suggestion, :search_reference, value: 'test')
      end

      it 'returns search suggestions' do
        expect(fuzzy_search.pluck(:value)).to contain_exactly('alu', 'aluminium wire', 'nuts, aluminium', 'bars - aluminium')
      end

      it 'returns search suggestions with a score' do
        expect(fuzzy_search.pluck(:score)).to include_json(
          [
            be_within(0.2).of(1.0),
            be_within(0.2).of(0.1875),
            be_within(0.2).of(0.1875),
            be_within(0.2).of(0.1875),
          ],
        )
      end

      it 'returns search suggestions with a query' do
        expect(fuzzy_search.pluck(:query)).to all(eq(query))
      end
    end

    context 'when the query is a 10 digit number' do
      let(:query) { '1234567890' }

      before do
        create(:search_suggestion, :goods_nomenclature, id: 'abc', value: '1234567890')
        create(:search_suggestion, :goods_nomenclature, id: 'def', value: '1234567890')
        create(:search_suggestion, :goods_nomenclature, value: '1234567891')
      end

      it 'returns search suggestions' do
        expect(fuzzy_search.pluck(:value)).to eq(
          %w[
            1234567890
          ],
        )
      end
    end

    context 'when the query is a number that is not 10 digits' do
      let(:query) { '12' }

      before do
        TradeTariffRequest.time_machine_now = Time.current

        create(
          :search_suggestion,
          :goods_nomenclature,
          goods_nomenclature: create(:commodity, goods_nomenclature_item_id: '1234567890'),
          value: '1234567890',
        )
        create(
          :search_suggestion,
          :goods_nomenclature,
          goods_nomenclature: create(:heading, goods_nomenclature_item_id: '1234000000'),
          value: '1234',
        )
        create(
          :search_suggestion,
          :goods_nomenclature,
          goods_nomenclature: create(:commodity, producline_suffix: '10', goods_nomenclature_item_id: '1235009000'),
          value: '1235009',
        )
        create(
          :search_suggestion,
          :goods_nomenclature,
          goods_nomenclature: create(:chapter, goods_nomenclature_item_id: '1200000000'),
          value: '12',
        )
      end

      it 'returns search suggestions' do
        expect(fuzzy_search.pluck(:value)).to eq(
          %w[
            12
            1234
            1235009
            1234567890
          ],
        )
      end
    end

    context 'when the query is an empty string' do
      let(:query) { '' }

      before do
        create(:search_suggestion, :goods_nomenclature, value: '') # control
      end

      it 'returns an empty array' do
        expect(fuzzy_search).to be_empty
      end
    end

    context 'when the query is nil' do
      let(:query) { nil }

      it 'returns an empty array' do
        expect(fuzzy_search).to be_empty
      end
    end
  end

  describe '.by_value' do
    context 'when the search suggestion exists and we only pass the value' do
      subject(:by_value) { described_class.by_value('gold ore') }

      before do
        create(:search_suggestion, :search_reference, value: 'gold ore')
      end

      it { is_expected.to be_one }
    end

    context 'when the search suggestion exists and we only pass the id and value' do
      subject(:by_value) { described_class.by_value('gold ore', 'abc') }

      before do
        create(:search_suggestion, :search_reference, id: 'abc', value: 'gold ore')
      end

      it { is_expected.to be_one }
    end

    context 'when the search suggestion does not exist' do
      subject(:by_value) { described_class.by_value('gold ore') }

      it { is_expected.to be_empty }
    end
  end

  describe '.goods_nomenclature_type' do
    subject(:goods_nomenclature_type) { described_class.goods_nomenclature_type.sql }

    it { is_expected.to include("WHERE (\"type\" = 'goods_nomenclature')") }
  end

  describe '.text_type' do
    subject(:text_type) { described_class.text_type.select_map(:value) }

    before do
      create(:search_suggestion, :search_reference, value: 'gold ore')
      create(:search_suggestion, :full_chemical_name, value: 'ore')
    end

    it { is_expected.to eq(['gold ore', 'ore']) }
  end

  describe '.numeric_type' do
    subject(:numeric_type) { described_class.numeric_type.select_map(:value) }

    before do
      create(:search_suggestion, :goods_nomenclature, value: '1234')
      create(:search_suggestion, :full_chemical_cus, value: '0154438-3')
      create(:search_suggestion, :full_chemical_cas, value: '8028-66-8')
    end

    it { is_expected.to eq(%w[1234 0154438-3 8028-66-8]) }
  end

  describe '.build' do
    subject(:build) { described_class.build(attributes) }

    let(:attributes) do
      {
        value: 'gold ore',
        type: 'search_reference',
        goods_nomenclature_sid: 1_234_567_890,
        goods_nomenclature_class: 'Heading',
      }
    end

    it { expect(build.priority).to eq(1) }
    it { expect(build).to be_a(described_class) }
    it { expect(build).to have_attributes(attributes) }
  end

  describe '.priority_for' do
    subject(:priority_for) { described_class.priority_for(suggestion) }

    let(:suggestion) { build(:search_suggestion, type:, goods_nomenclature_class:) }

    context 'when the type is a search reference' do
      let(:type) { 'search_reference' }
      let(:goods_nomenclature_class) { 'Heading' }

      it { is_expected.to eq(1) }
    end

    context 'when the type is a full chemical name' do
      let(:type) { 'full_chemical_name' }
      let(:goods_nomenclature_class) { 'Heading' }

      it { is_expected.to eq(2) }
    end

    context 'when the type is a goods nomenclature' do
      let(:type) { 'goods_nomenclature' }

      context 'when the goods nomenclature class is a chapter' do
        let(:goods_nomenclature_class) { 'Chapter' }

        it { is_expected.to eq(1) }
      end

      context 'when the goods nomenclature class is a heading' do
        let(:goods_nomenclature_class) { 'Heading' }

        it { is_expected.to eq(2) }
      end

      context 'when the goods nomenclature class is a subheading' do
        let(:goods_nomenclature_class) { 'Subheading' }

        it { is_expected.to eq(3) }
      end

      context 'when the goods nomenclature class is a commodity' do
        let(:goods_nomenclature_class) { 'Commodity' }

        it { is_expected.to eq(4) }
      end

      context 'when the goods nomenclature class is unknown' do
        let(:goods_nomenclature_class) { 'Unknown' }

        it { is_expected.to eq(5) }
      end
    end

    context 'when the type is a full chemical cus' do
      let(:type) { 'full_chemical_cus' }
      let(:goods_nomenclature_class) { 'Heading' }

      it { is_expected.to eq(5) }
    end

    context 'when the type is a full chemical cas' do
      let(:type) { 'full_chemical_cas' }
      let(:goods_nomenclature_class) { 'Heading' }

      it { is_expected.to eq(6) }
    end

    context 'when the type is unknown' do
      let(:type) { 'unknown' }
      let(:goods_nomenclature_class) { 'Heading' }

      it { is_expected.to be_nil }
    end
  end
end
