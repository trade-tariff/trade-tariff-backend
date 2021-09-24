RSpec.describe SearchService do
  def commodity_pattern(item)
    {
      type: 'exact_match',
      entry: {
        endpoint: 'commodities',
        id: item.goods_nomenclature_item_id.first(10),
      },
    }
  end

  let(:data_serializer) { Api::V1::SearchSerializationService.new }

  describe 'initialization' do
    let(:query) { Forgery(:basic).text }

    it 'assigns search query' do
      expect(
        described_class.new(data_serializer, q: query).q,
      ).to eq query
    end

    it 'strips [, ] characters from search query' do
      expect(
        described_class.new(data_serializer, q: '[hello] [world]').q,
      ).to eq 'hello world'
    end
  end

  describe '#valid?' do
    it 'is valid if has no q param assigned' do
      expect(
        described_class.new(data_serializer, q: nil),
      ).to be_valid
    end

    it 'is valid if has no as_of param assigned' do
      expect(
        described_class.new(data_serializer, q: 'value'),
      ).to be_valid
    end

    it 'is valid if has both t and as_of params provided' do
      expect(
        described_class.new(data_serializer, q: 'value', as_of: Date.current),
      ).to be_valid
    end
  end

  # Searching in local tables
  describe 'exact search' do
    around do |example|
      TimeMachine.now { example.run }
    end

    context 'chapters' do
      context 'chapter goods id has not got preceding zero' do
        let(:chapter) { create :chapter, goods_nomenclature_item_id: '1100000000' }
        let(:pattern) do
          {
            type: 'exact_match',
            entry: {
              endpoint: 'chapters',
              id: chapter.goods_nomenclature_item_id.first(2),
            },
          }
        end

        it 'returns endpoint and identifier if provided with 2 digit chapter code' do
          result = described_class.new(data_serializer,
                                       q: chapter.goods_nomenclature_item_id.first(2),
                                       as_of: Date.current).to_json

          expect(result).to match_json_expression pattern
        end

        it 'returns endpoint and identifier if provided with matching 3 digit chapter code' do
          result = described_class.new(data_serializer,
                                       q: chapter.goods_nomenclature_item_id.first(2),
                                       as_of: Date.current).to_json

          expect(result).to match_json_expression pattern
        end
      end

      context 'chapter goods code id has got preceding zero' do
        let(:chapter) { create :chapter, goods_nomenclature_item_id: '0800000000' }
        let(:pattern) do
          {
            type: 'exact_match',
            entry: {
              endpoint: 'chapters',
              id: "0#{chapter.goods_nomenclature_item_id[1, 1]}",
            },
          }
        end

        it 'returns endpoint and identifier if provided with 1 digit chapter code' do
          result = described_class.new(data_serializer,
                                       q: chapter.goods_nomenclature_item_id.first(2),
                                       as_of: Date.current).to_json

          expect(result).to match_json_expression pattern
        end
      end
    end

    context 'headings' do
      let(:heading) { create :heading }
      let(:pattern) do
        {
          type: 'exact_match',
          entry: {
            endpoint: 'headings',
            id: heading.goods_nomenclature_item_id.first(4),
          },
        }
      end

      it 'returns endpoint and identifier if provided with 4 symbol heading code' do
        result = described_class.new(data_serializer,
                                     q: heading.goods_nomenclature_item_id.first(4),
                                     as_of: Date.current).to_json

        expect(result).to match_json_expression pattern
      end

      it 'returns endpoint and identifier if provided with matching 6 (or any between length of 4 to 9) symbol heading code' do
        result = described_class.new(data_serializer,
                                     q: heading.goods_nomenclature_item_id.first(6),
                                     as_of: Date.current).to_json

        expect(result).to match_json_expression pattern
      end

      it 'returns endpoint and identifier if provided with matching 10 symbol declarable heading code' do
        result = described_class.new(data_serializer,
                                     q: heading.goods_nomenclature_item_id,
                                     as_of: Date.current).to_json

        expect(result).to match_json_expression pattern
      end
    end

    context 'commodities' do
      context 'declarable' do
        let(:commodity) { create :commodity, :declarable, :with_heading, :with_indent }
        let(:heading)   { commodity.heading }
        let(:chemical)  { create :chemical, :with_name }

        let(:heading_pattern) do
          {
            type: 'exact_match',
            entry: {
              endpoint: 'headings',
              id: heading.goods_nomenclature_item_id.first(4),
            },
          }
        end

        it 'returns endpoint and identifier if provided with 10 symbol commodity code' do
          result = described_class.new(data_serializer,
                                       q: commodity.goods_nomenclature_item_id.first(10),
                                       as_of: Date.current).to_json

          expect(result).to match_json_expression commodity_pattern(commodity)
        end

        it 'returns endpoint and identifier if provided with 10 symbol commodity code separated by spaces' do
          code = [commodity.goods_nomenclature_item_id[0..1],
                  commodity.goods_nomenclature_item_id[2..3],
                  commodity.goods_nomenclature_item_id[4..5],
                  commodity.goods_nomenclature_item_id[6..7],
                  commodity.goods_nomenclature_item_id[8..9]].join('')
          result = described_class.new(data_serializer, q: code,
                                                        as_of: Date.current).to_json

          expect(result).to match_json_expression commodity_pattern(commodity)
        end

        it 'returns endpoint and identifier if provided with 10 digits separated by whitespace of varying length' do
          code =  [commodity.goods_nomenclature_item_id[0..1],
                   commodity.goods_nomenclature_item_id[2..3]].join('')
          code << [commodity.goods_nomenclature_item_id[4..5],
                   commodity.goods_nomenclature_item_id[6..7]].join('     ')
          code << '  ' << commodity.goods_nomenclature_item_id[8..9]

          result = described_class.new(data_serializer, q: code,
                                                        as_of: Date.current).to_json

          expect(result).to match_json_expression commodity_pattern(commodity)
        end

        it 'returns endpoint and identifier if provided with 10 symbol commodity code separated by dots' do
          code = [commodity.goods_nomenclature_item_id[0..1],
                  commodity.goods_nomenclature_item_id[2..3],
                  commodity.goods_nomenclature_item_id[4..5],
                  commodity.goods_nomenclature_item_id[6..7],
                  commodity.goods_nomenclature_item_id[8..9]].join('.')
          result = described_class.new(data_serializer, q: code,
                                                        as_of: Date.current).to_json

          expect(result).to match_json_expression commodity_pattern(commodity)
        end

        it 'returns endpoint and identifier if provided with 10 digits separated by various non number characters' do
          code =  [commodity.goods_nomenclature_item_id[0..1],
                   commodity.goods_nomenclature_item_id[2..3]].join('|')
          code << [commodity.goods_nomenclature_item_id[4..5],
                   commodity.goods_nomenclature_item_id[6..7]].join('!!  !!!')
          code << '  ' << commodity.goods_nomenclature_item_id[8..9]

          result = described_class.new(data_serializer, q: code,
                                                        as_of: Date.current).to_json

          expect(result).to match_json_expression commodity_pattern(commodity)
        end

        it 'returns endpoint and identifier if provided with matching 12 symbol commodity code' do
          result = described_class.new(data_serializer, q: commodity.goods_nomenclature_item_id + commodity.producline_suffix,
                                                        as_of: Date.current).to_json

          expect(result).to match_json_expression commodity_pattern(commodity)
        end
      end

      context 'non declarable' do
        let!(:heading) do
          create :heading, goods_nomenclature_item_id: '8418000000',
                           validity_start_date: Date.new(2011, 1, 1)
        end
        let!(:commodity1) do
          create :commodity, :with_indent,
                 indents: 3,
                 goods_nomenclature_item_id: '8418213100',
                 producline_suffix: '80',
                 validity_start_date: Date.new(2011, 1, 1)
        end
        let!(:commodity2) do
          create :commodity, :with_indent,
                 indents: 4,
                 goods_nomenclature_item_id: '8418215100',
                 producline_suffix: '80',
                 validity_start_date: Date.new(2011, 1, 1)
        end

        let(:heading_pattern) do
          {
            type: 'exact_match',
            entry: {
              endpoint: 'headings',
              id: heading.goods_nomenclature_item_id.first(4),
            },
          }
        end

        it 'does not exact match commodity with children' do
          # even though productline suffix (80) suggests that it is declarable
          result = described_class.new(data_serializer, q: commodity1.goods_nomenclature_item_id,
                                                        as_of: Date.current).to_json

          expect(result).to match_json_expression heading_pattern
        end
      end

      context 'codes mapping' do
        let!(:commodity1) { create :commodity, :declarable, :with_heading, :with_indent, goods_nomenclature_item_id: '1010111255' }
        let!(:commodity2) { create :commodity, :declarable, :with_heading, :with_indent, goods_nomenclature_item_id: '2210113355' }

        it 'returns mapped commodity' do
          result = described_class.new(data_serializer, q: '1010111255',
                                                        as_of: Date.current).to_json

          expect(result).to match_json_expression commodity_pattern(commodity2)
        end
      end
    end

    context 'chemicals' do
      let(:commodity) { create :commodity, :declarable, :with_heading, :with_indent }
      let(:chemical)  { create :chemical, :with_name }
      let(:relation)  { create :chemicals_goods_nomenclatures, chemical_id: chemical.id, goods_nomenclature_sid: commodity.goods_nomenclature_sid }

      before { relation }

      it 'returns endpoint and identifier if provided with CAS number with the leading string "cas "' do
        result = described_class.new(
          data_serializer,
          q: "cas #{chemical.cas}",
          as_of: Date.current,
        ).to_json

        expect(result).to match_json_expression commodity_pattern(commodity)
      end

      it 'returns endpoint and identifier if provided with CAS number only' do
        result = described_class.new(
          data_serializer,
          q: chemical.cas,
          as_of: Date.current,
        ).to_json

        expect(result).to match_json_expression commodity_pattern(commodity)
      end
    end

    context 'hidden commodities' do
      let!(:commodity)    { create :commodity, :declarable }
      let!(:hidden_gono)  { create :hidden_goods_nomenclature, goods_nomenclature_item_id: commodity.goods_nomenclature_item_id }

      before do
        @result = described_class.new(data_serializer, q: commodity.goods_nomenclature_item_id.first(10),
                                                       as_of: Date.current).to_json
      end

      it 'does not return hidden commodity as exact match' do
        expect(@result).not_to match_json_expression commodity_pattern(commodity)
      end
    end
  end

  # Searching in ElasticSearch index
  describe 'fuzzy search' do
    context 'filtering by date' do
      context 'with goods codes that have bounded validity period' do
        let!(:heading) do
          create :heading, :with_description,
                 goods_nomenclature_item_id: '2851000000',
                 validity_start_date: Date.new(1972, 1, 1),
                 validity_end_date: Date.new(2006, 12, 31),
                 description: 'Other inorganic compounds (including distilled or conductivity water and water of similar purity);'
        end

        # heading that has validity period of 1972-01-01 to 2006-12-31
        let(:heading_pattern) do
          {
            type: 'fuzzy_match',
            goods_nomenclature_match: {
              headings: [
                { '_source' => {
                  'goods_nomenclature_item_id' => '2851000000',
                }.ignore_extra_keys! }.ignore_extra_keys!,
              ].ignore_extra_values!,
            }.ignore_extra_keys!,
          }.ignore_extra_keys!
        end

        it 'returns goods code if search date falls within validity period' do
          @result = described_class.new(data_serializer, q: 'water',
                                                         as_of: '2005-01-01').to_json

          expect(@result).to match_json_expression heading_pattern
        end

        it 'does not return goods code if search date does not fall within validity period' do
          @result = described_class.new(data_serializer, q: 'water',
                                                         as_of: '2007-01-01').to_json

          expect(@result).not_to match_json_expression heading_pattern
        end
      end

      context 'with goods codes that have unbounded validity period' do
        let!(:heading) do
          create :heading, :with_description,
                 goods_nomenclature_item_id: '0102000000',
                 validity_start_date: Date.new(1972, 1, 1),
                 validity_end_date: nil,
                 description: 'Live bovine animals'
        end

        # heading that has validity period starting from 1972-01-01
        let(:heading_pattern) do
          {
            type: 'fuzzy_match',
            goods_nomenclature_match: {
              headings: [
                { '_source' => {
                  'goods_nomenclature_item_id' => '0102000000',
                }.ignore_extra_keys! }.ignore_extra_keys!,
              ].ignore_extra_values!,
            }.ignore_extra_keys!,
          }.ignore_extra_keys!
        end

        it 'returns goods code if search date is greater than start of validity period' do
          @result = described_class.new(data_serializer, q: 'bovine animal',
                                                         as_of: '2007-01-01').to_json

          expect(@result).to match_json_expression heading_pattern
        end

        it 'does not return goods code if search date is less than start of validity period' do
          @result = described_class.new(data_serializer, q: 'bovine animal',
                                                         as_of: '1970-01-01').to_json

          expect(@result).not_to match_json_expression heading_pattern
        end
      end
    end

    describe 'querying with ambiguous characters' do
      # Ensure we use match (not query_string query)
      # query string interprets queries according to Lucene syntax
      # and we don't need these advanced features

      let(:result) do
        described_class.new(data_serializer, q: '!!! [t_e_s_t][',
                                             as_of: '1970-01-01')
      end

      specify 'search does not raise an exception' do
        expect { result.to_json }.not_to raise_error
      end

      specify 'search returns empty resilt' do
        expect(result.to_json).to match_json_expression SearchService::BaseSearch::BLANK_RESULT.merge(type: 'fuzzy_match')
      end
    end

    context 'searching for sections' do
      # Sections do not have validity periods
      # We have to ensure there is special clause in Elasticsearch
      # query that takes that into account and they get found
      let(:title) { 'example title' }
      let!(:section) { create :section, title: title }
      let(:result) do
        described_class.new(data_serializer, q: title,
                                             as_of: '1970-01-01')
      end
      let(:response_pattern) do
        {
          type: 'fuzzy_match',
          goods_nomenclature_match: {
            sections: [
              { '_source' => {
                'title' => title,
              }.ignore_extra_keys! }.ignore_extra_keys!,
            ].ignore_extra_values!,
          }.ignore_extra_keys!,
        }.ignore_extra_keys!
      end

      it 'finds relevant sections' do
        expect(result.to_json).to match_json_expression response_pattern
      end
    end

    context 'searching with synonyms' do
      include SynonymsHelper

      let(:synonym) { 'synonym 1' }
      let(:resources) { %w[section chapter heading commodity] }
      let(:exact_match) do
        described_class.new(data_serializer, q: synonym, as_of: Date.current).send(:perform).results
      end

      before do
        # create resources with synonyms
        resources.each do |resource|
          create(resource).tap do |r|
            2.times do
              create_synonym_for(r, synonym)
            end
          end
        end
      end

      # there shouldn't be duplicates
      it 'returns first created search reference' do
        expect(exact_match).to be_a(Section)
      end
    end
  end

  context 'reference search' do
    describe 'validity period function' do
      let!(:heading) do
        create :heading, :with_description,
               goods_nomenclature_item_id: '2851000000',
               validity_start_date: Date.new(1972, 1, 1),
               validity_end_date: Date.new(2006, 12, 31),
               description: 'Test'
      end
      let!(:search_reference) do
        create :search_reference,
               referenced: heading,
               title: 'water'
      end

      let(:heading_pattern) do
        {
          type: 'exact_match',
          entry: {
            endpoint: 'headings',
            id: heading.goods_nomenclature_item_id.first(4),
          }.ignore_extra_keys!,
        }.ignore_extra_keys!
      end

      before do
        travel_to Date.parse('17-05-2006')
      end

      after do
        travel_back
      end

      it 'returns goods code if search date falls within validity period' do
        @result = described_class.new(data_serializer, q: 'water',
                                                       as_of: '2005-01-01').to_json

        expect(@result).to match_json_expression heading_pattern
      end

      it 'does not return goods code if search date does not fall within validity period' do
        @result = described_class.new(data_serializer, q: 'water',
                                                       as_of: '2007-01-01').to_json

        expect(@result).not_to match_json_expression heading_pattern
      end
    end

    describe 'reference matching for multi term searches' do
      let!(:heading1) do
        create :heading, :with_description,
               goods_nomenclature_item_id: '2851000000',
               description: 'Test 1'
      end
      let!(:search_reference1) do
        create :search_reference,
               referenced: heading1,
               title: 'acid oil'
      end
      let!(:heading2) do
        create :heading, :with_description,
               goods_nomenclature_item_id: '2920000000',
               description: 'Test 2'
      end
      let!(:search_reference2) do
        create :search_reference,
               referenced: heading2,
               title: 'other kind of oil'
      end

      let(:heading_pattern) do
        {
          type: 'exact_match',
          entry: {
            endpoint: 'headings',
            id: heading1.goods_nomenclature_item_id.first(4),
          }.ignore_extra_keys!,
        }.ignore_extra_keys!
      end

      it 'only matches exact phrases' do
        @result = described_class.new(data_serializer, q: 'acid oil',
                                                       as_of: Date.current).to_json

        expect(@result).to match_json_expression heading_pattern
      end
    end
  end

  describe '#persisted?' do
    it 'returns false' do
      expect(described_class.new(data_serializer, q: '123')).not_to be_persisted
    end
  end
end
