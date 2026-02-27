RSpec.describe CompositeSearchTextBuilder do
  subject(:builder) { described_class.new(self_text_record, labels: label, search_references: refs) }

  let(:self_text_record) do
    build(:goods_nomenclature_self_text,
          goods_nomenclature_sid: 1,
          self_text: 'Live horses (excl. for slaughter)')
  end

  let(:label) { nil }
  let(:refs) { nil }

  describe '#call' do
    context 'with only a self-text description' do
      it 'returns just the description' do
        expect(builder.call).to eq('Live horses (excl. for slaughter)')
      end
    end

    context 'with labels containing synonyms and colloquial terms' do
      let(:label) do
        build(:goods_nomenclature_label,
              goods_nomenclature_sid: 1,
              labels: {
                'colloquial_terms' => %w[ponies equines],
                'synonyms' => %w[stallions],
                'known_brands' => [],
              },
              colloquial_terms: Sequel.pg_array(%w[ponies equines], :text),
              synonyms: Sequel.pg_array(%w[stallions], :text),
              known_brands: Sequel.pg_array([], :text))
      end

      it 'includes also known as section' do
        result = builder.call
        expect(result).to include('Also known as: ponies, equines, stallions')
        expect(result).not_to include('Brands:')
      end
    end

    context 'with labels containing known brands' do
      let(:label) do
        build(:goods_nomenclature_label,
              goods_nomenclature_sid: 1,
              labels: {
                'colloquial_terms' => [],
                'synonyms' => [],
                'known_brands' => %w[BrandA BrandB],
              },
              colloquial_terms: Sequel.pg_array([], :text),
              synonyms: Sequel.pg_array([], :text),
              known_brands: Sequel.pg_array(%w[BrandA BrandB], :text))
      end

      it 'includes brands section' do
        result = builder.call
        expect(result).to include('Brands: BrandA, BrandB')
      end
    end

    context 'with search references' do
      let(:refs) do
        [
          build(:search_reference, title: 'horses'),
          build(:search_reference, title: 'live animals'),
        ]
      end

      it 'includes references section' do
        result = builder.call
        expect(result).to include('References: horses, live animals')
      end
    end

    context 'with all data present' do
      let(:label) do
        build(:goods_nomenclature_label,
              goods_nomenclature_sid: 1,
              labels: {
                'colloquial_terms' => %w[ponies],
                'synonyms' => %w[equines],
                'known_brands' => %w[Thoroughbred],
              },
              colloquial_terms: Sequel.pg_array(%w[ponies], :text),
              synonyms: Sequel.pg_array(%w[equines], :text),
              known_brands: Sequel.pg_array(%w[Thoroughbred], :text))
      end

      let(:refs) do
        [build(:search_reference, title: 'horses')]
      end

      it 'assembles all sections in order' do
        result = builder.call
        lines = result.split("\n")

        expect(lines[0]).to eq('Live horses (excl. for slaughter)')
        expect(lines[1]).to eq('Also known as: ponies, equines')
        expect(lines[2]).to eq('Brands: Thoroughbred')
        expect(lines[3]).to eq('References: horses')
      end
    end

    context 'with blank values in label arrays' do
      let(:label) do
        build(:goods_nomenclature_label,
              goods_nomenclature_sid: 1,
              labels: {
                'colloquial_terms' => ['ponies', '', nil],
                'synonyms' => [],
                'known_brands' => ['', nil],
              },
              colloquial_terms: Sequel.pg_array(['ponies', '', nil], :text),
              synonyms: Sequel.pg_array([], :text),
              known_brands: Sequel.pg_array(['', nil], :text))
      end

      it 'filters out blank values' do
        result = builder.call
        expect(result).to include('Also known as: ponies')
        expect(result).not_to include('Brands:')
      end
    end

    context 'with nil labels hash field' do
      let(:label) do
        build(:goods_nomenclature_label,
              goods_nomenclature_sid: 1,
              labels: {
                'colloquial_terms' => nil,
                'synonyms' => nil,
                'known_brands' => nil,
              },
              colloquial_terms: nil,
              synonyms: nil,
              known_brands: nil)
      end

      it 'returns just the description' do
        expect(builder.call).to eq('Live horses (excl. for slaughter)')
      end
    end
  end

  describe '.batch' do
    let(:self_text_1) do
      create(:goods_nomenclature_self_text,
             goods_nomenclature_sid: commodity_1.goods_nomenclature_sid,
             goods_nomenclature_item_id: commodity_1.goods_nomenclature_item_id,
             self_text: 'Description one')
    end

    let(:self_text_2) do
      create(:goods_nomenclature_self_text,
             goods_nomenclature_sid: commodity_2.goods_nomenclature_sid,
             goods_nomenclature_item_id: commodity_2.goods_nomenclature_item_id,
             self_text: 'Description two')
    end

    let(:commodity_1) { create(:commodity, :with_description, :declarable) }
    let(:commodity_2) { create(:commodity, :with_description, :declarable) }

    it 'returns composite text keyed by SID' do
      records = [self_text_1, self_text_2]
      result = described_class.batch(records)

      expect(result.keys).to contain_exactly(
        commodity_1.goods_nomenclature_sid,
        commodity_2.goods_nomenclature_sid,
      )
      expect(result[commodity_1.goods_nomenclature_sid]).to eq('Description one')
      expect(result[commodity_2.goods_nomenclature_sid]).to eq('Description two')
    end

    it 'returns empty hash for empty input' do
      expect(described_class.batch([])).to eq({})
    end

    it 'includes ancestor search references' do
      chapter = create(:chapter, goods_nomenclature_item_id: '8400000000')
      heading = create(:heading, parent: chapter, goods_nomenclature_item_id: '8418000000')
      commodity = create(:commodity, :with_description, :declarable,
                         parent: heading,
                         goods_nomenclature_item_id: '8418215190')
      self_text = create(:goods_nomenclature_self_text,
                         goods_nomenclature_sid: commodity.goods_nomenclature_sid,
                         goods_nomenclature_item_id: commodity.goods_nomenclature_item_id,
                         self_text: 'A fridge commodity')

      create(:search_reference, title: 'fridges', referenced: heading)

      result = described_class.batch([self_text])

      expect(result[commodity.goods_nomenclature_sid]).to include('References: fridges')
    end
  end
end
