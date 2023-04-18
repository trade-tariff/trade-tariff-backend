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
        described_class.new(data_serializer, q: 'value', as_of: Time.zone.today),
      ).to be_valid
    end
  end

  # Searching in local tables
  describe 'exact search' do
    around do |example|
      TimeMachine.now { example.run }
    end

    context 'when chapters' do
      context 'when chapter goods id has not got preceding zero' do
        let(:chapter) { create :chapter, goods_nomenclature_item_id: '1100000000' }
        let(:pattern) do
          {
            type: 'exact_match',
            entry: {
              endpoint: 'chapters',
              id: chapter.short_code,
            },
          }
        end

        it 'returns endpoint and identifier if provided with 2 digit chapter code' do
          result = described_class.new(data_serializer,
                                       q: chapter.goods_nomenclature_item_id.first(2),
                                       as_of: Time.zone.today).to_json

          expect(result).to match_json_expression pattern
        end
      end

      context 'when chapter goods code id has got preceding zero' do
        let(:chapter) { create :chapter, goods_nomenclature_item_id: '0800000000' }
        let(:pattern) do
          {
            type: 'exact_match',
            entry: {
              endpoint: 'chapters',
              id: chapter.short_code,
            },
          }
        end

        it 'returns endpoint and identifier if provided with 1 digit chapter code' do
          result = described_class.new(data_serializer,
                                       q: chapter.goods_nomenclature_item_id.first(2),
                                       as_of: Time.zone.today).to_json

          expect(result).to match_json_expression pattern
        end
      end
    end

    context 'when headings' do
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
                                     as_of: Time.zone.today).to_json

        expect(result).to match_json_expression pattern
      end

      it 'returns endpoint and identifier if provided with matching 6 (or any between length of 4 to 9) symbol heading code' do
        result = described_class.new(data_serializer,
                                     q: heading.goods_nomenclature_item_id.first(6),
                                     as_of: Time.zone.today).to_json

        expect(result).to match_json_expression pattern
      end

      it 'returns endpoint and identifier if provided with matching 10 symbol declarable heading code' do
        result = described_class.new(data_serializer,
                                     q: heading.goods_nomenclature_item_id,
                                     as_of: Time.zone.today).to_json

        expect(result).to match_json_expression pattern
      end
    end

    context 'when commodities' do
      context 'when declarable' do
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
                                       as_of: Time.zone.today).to_json

          expect(result).to match_json_expression commodity_pattern(commodity)
        end

        it 'returns endpoint and identifier if provided with 6 symbol commoditity code' do
          commodity = create(:commodity, :declarable, :with_heading, :with_indent,
                             goods_nomenclature_item_id: '0101010000')

          result = described_class.new(data_serializer,
                                       q: '010101',
                                       as_of: Time.zone.today).to_json

          expect(result).to match_json_expression commodity_pattern(commodity)
        end

        it 'returns endpoint and identifier if provided with 8 symbol commoditity code' do
          commodity = create(:commodity, :declarable, :with_heading, :with_indent,
                             goods_nomenclature_item_id: '0101010100')

          result = described_class.new(data_serializer,
                                       q: '01010101',
                                       as_of: Time.zone.today).to_json

          expect(result).to match_json_expression commodity_pattern(commodity)
        end

        it 'returns endpoint and identifier if provided with 10 symbol commodity code separated by spaces' do
          code = [commodity.goods_nomenclature_item_id[0..1],
                  commodity.goods_nomenclature_item_id[2..3],
                  commodity.goods_nomenclature_item_id[4..5],
                  commodity.goods_nomenclature_item_id[6..7],
                  commodity.goods_nomenclature_item_id[8..9]].join('')
          result = described_class.new(data_serializer, q: code,
                                                        as_of: Time.zone.today).to_json

          expect(result).to match_json_expression commodity_pattern(commodity)
        end

        it 'returns endpoint and identifier if provided with 10 digits separated by whitespace of varying length' do
          code =  [commodity.goods_nomenclature_item_id[0..1],
                   commodity.goods_nomenclature_item_id[2..3]].join('')
          code << [commodity.goods_nomenclature_item_id[4..5],
                   commodity.goods_nomenclature_item_id[6..7]].join('     ')
          code << '  ' << commodity.goods_nomenclature_item_id[8..9]

          result = described_class.new(data_serializer, q: code,
                                                        as_of: Time.zone.today).to_json

          expect(result).to match_json_expression commodity_pattern(commodity)
        end

        it 'returns endpoint and identifier if provided with 10 symbol commodity code separated by dots' do
          code = [commodity.goods_nomenclature_item_id[0..1],
                  commodity.goods_nomenclature_item_id[2..3],
                  commodity.goods_nomenclature_item_id[4..5],
                  commodity.goods_nomenclature_item_id[6..7],
                  commodity.goods_nomenclature_item_id[8..9]].join('.')
          result = described_class.new(data_serializer, q: code,
                                                        as_of: Time.zone.today).to_json

          expect(result).to match_json_expression commodity_pattern(commodity)
        end

        it 'returns endpoint and identifier if provided with 10 digits separated by various non number characters' do
          code =  [commodity.goods_nomenclature_item_id[0..1],
                   commodity.goods_nomenclature_item_id[2..3]].join('|')
          code << [commodity.goods_nomenclature_item_id[4..5],
                   commodity.goods_nomenclature_item_id[6..7]].join('!!  !!!')
          code << '  ' << commodity.goods_nomenclature_item_id[8..9]

          result = described_class.new(data_serializer, q: code,
                                                        as_of: Time.zone.today).to_json

          expect(result).to match_json_expression commodity_pattern(commodity)
        end

        it 'returns endpoint and identifier if provided with matching 12 symbol commodity code' do
          result = described_class.new(data_serializer, q: commodity.goods_nomenclature_item_id + commodity.producline_suffix,
                                                        as_of: Time.zone.today).to_json

          expect(result).to match_json_expression commodity_pattern(commodity)
        end
      end

      context 'when non declarable' do
        before do
          create :heading, goods_nomenclature_item_id: '8418000000',
                           validity_start_date: Date.new(2011, 1, 1)

          create :commodity, :with_indent,
                 indents: 4,
                 goods_nomenclature_item_id: '8418215100',
                 producline_suffix: '80',
                 validity_start_date: Date.new(2011, 1, 1)
        end

        let!(:commodity) do
          create :commodity, :with_indent,
                 indents: 3,
                 goods_nomenclature_item_id: '8418213100',
                 producline_suffix: '80',
                 validity_start_date: Date.new(2011, 1, 1)
        end

        let(:subheading_pattern) do
          {
            type: 'exact_match',
            entry: {
              endpoint: 'subheadings',
              id: '8418213100-80',
            },
          }
        end

        it 'does not exact match commodity with children' do
          # even though productline suffix (80) suggests that it is declarable
          result = described_class.new(data_serializer, q: commodity.goods_nomenclature_item_id,
                                                        as_of: Time.zone.today).to_json

          expect(result).to match_json_expression subheading_pattern
        end
      end

      context 'when codes mapping' do
        before do
          create :commodity, :declarable, :with_heading, :with_indent, goods_nomenclature_item_id: '1010111255'
        end

        let!(:commodity) { create :commodity, :declarable, :with_heading, :with_indent, goods_nomenclature_item_id: '2210113355' }

        it 'returns mapped commodity' do
          result = described_class.new(data_serializer, q: '1010111255', as_of: Time.zone.today).to_json

          expect(result).to match_json_expression commodity_pattern(commodity)
        end
      end

      context 'when unknown commodity' do
        let(:pattern) do
          {
            type: 'fuzzy_match',
            goods_nomenclature_match: {
              chapters: [],
              commodities: [],
              headings: [],
              sections: [],
            },
            reference_match: {
              chapters: [],
              commodities: [],
              headings: [],
              sections: [],
            },
          }
        end

        context 'when under unknown heading' do
          it 'returns empty result' do
            result = described_class.new(data_serializer,
                                         q: '8418999999',
                                         as_of: Time.zone.today).to_json

            expect(result).to match_json_expression pattern
          end
        end

        context 'when under known heading' do
          before do
            create :heading, goods_nomenclature_item_id: '8418000000',
                             validity_start_date: Date.new(2011, 1, 1)
          end

          it 'returns empty result' do
            result = described_class.new(data_serializer,
                                         q: '8418999999',
                                         as_of: Time.zone.today).to_json

            expect(result).to match_json_expression pattern
          end
        end
      end
    end

    context 'when chemicals' do
      let(:commodity) { create :commodity, :declarable, :with_heading, :with_indent }
      let(:chemical)  { create :chemical, :with_name }
      let(:relation)  { create :chemicals_goods_nomenclatures, chemical_id: chemical.id, goods_nomenclature_sid: commodity.goods_nomenclature_sid }

      before { relation }

      it 'returns endpoint and identifier if provided with CAS number with the leading string "cas "' do
        result = described_class.new(
          data_serializer,
          q: "cas #{chemical.cas}",
          as_of: Time.zone.today,
        ).to_json

        expect(result).to match_json_expression commodity_pattern(commodity)
      end

      it 'returns endpoint and identifier if provided with CAS number only' do
        result = described_class.new(
          data_serializer,
          q: chemical.cas,
          as_of: Time.zone.today,
        ).to_json

        expect(result).to match_json_expression commodity_pattern(commodity)
      end
    end

    context 'when hidden commodities' do
      before do
        create :hidden_goods_nomenclature, goods_nomenclature_item_id: commodity.goods_nomenclature_item_id
      end

      let!(:commodity)    { create :commodity, :declarable }

      it 'does not return hidden commodity as exact match' do
        result = described_class.new(data_serializer, q: commodity.goods_nomenclature_item_id.first(10),
                                                      as_of: Time.zone.today).to_json
        expect(result).not_to match_json_expression commodity_pattern(commodity)
      end
    end

    context 'when search references' do
      subject(:result) { described_class.new(data_serializer, q: 'Foo Bar', as_of: Time.zone.today).to_json }

      before do
        create(
          :search_suggestion,
          :search_reference,
          goods_nomenclature: create(:heading, goods_nomenclature_item_id: '0102000000'),
          value: 'foo bar',
        )
      end

      let(:expected_pattern) do
        {
          type: 'exact_match',
          entry: {
            endpoint: 'headings',
            id: '0102',
          },
        }
      end

      it { is_expected.to match_json_expression(expected_pattern) }
    end
  end

  # Searching in ElasticSearch index
  describe 'fuzzy search' do
    context 'when filtering by date' do
      context 'when with goods codes that have bounded validity period' do
        before do
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
          result = described_class.new(data_serializer, q: 'water',
                                                        as_of: '2005-01-01').to_json

          expect(result).to match_json_expression heading_pattern
        end

        it 'does not return goods code if search date does not fall within validity period' do
          result = described_class.new(data_serializer, q: 'water',
                                                        as_of: '2007-01-01').to_json

          expect(result).not_to match_json_expression heading_pattern
        end
      end

      context 'when with goods codes that have unbounded validity period' do
        before do
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
          result = described_class.new(data_serializer, q: 'bovine animal',
                                                        as_of: '2007-01-01').to_json

          expect(result).to match_json_expression heading_pattern
        end

        it 'does not return goods code if search date is less than start of validity period' do
          result = described_class.new(data_serializer, q: 'bovine animal',
                                                        as_of: '1970-01-01').to_json

          expect(result).not_to match_json_expression heading_pattern
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

    context 'when searching for sections' do
      # Sections do not have validity periods
      # We have to ensure there is special clause in Elasticsearch
      # query that takes that into account and they get found
      before do
        create :section, title: 'example title'
      end

      let(:response_pattern) do
        {
          type: 'fuzzy_match',
          goods_nomenclature_match: {
            sections: [
              { '_source' => {
                'title' => 'example title',
              }.ignore_extra_keys! }.ignore_extra_keys!,
            ].ignore_extra_values!,
          }.ignore_extra_keys!,
        }.ignore_extra_keys!
      end

      it 'finds relevant sections' do
        result = described_class.new(data_serializer, q: 'example title',
                                                      as_of: '1970-01-01')
        expect(result.to_json).to match_json_expression response_pattern
      end
    end
  end

  context 'when reference search' do
    describe 'validity period function' do
      before do
        create :search_suggestion,
               goods_nomenclature: heading,
               value: 'water'
      end

      let!(:heading) do
        create :heading, :with_description,
               goods_nomenclature_item_id: '2851000000',
               validity_start_date: Date.new(1972, 1, 1),
               validity_end_date: Date.new(2006, 12, 31),
               description: 'Test'
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

      it 'returns goods code if search date falls within validity period' do
        result = TimeMachine.at('2005-01-01') { described_class.new(data_serializer, q: 'water').to_json }

        expect(result).to match_json_expression heading_pattern
      end

      it 'does not return goods code if search date does not fall within validity period' do
        result = TimeMachine.at('2007-01-01') { described_class.new(data_serializer, q: 'water').to_json }

        expect(result).not_to match_json_expression heading_pattern
      end
    end

    describe 'reference matching for multi term searches' do
      before do
        create :search_suggestion,
               :search_reference,
               goods_nomenclature: heading1,
               value: 'acid oil'

        create :search_suggestion,
               :search_reference,
               goods_nomenclature: heading2,
               value: 'other kind of oil'
      end

      let!(:heading1) do
        create :heading, :with_description,
               goods_nomenclature_item_id: '2851000000',
               description: 'Test 1'
      end
      let!(:heading2) do
        create :heading, :with_description,
               goods_nomenclature_item_id: '2920000000',
               description: 'Test 2'
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
        result = described_class.new(data_serializer, q: 'acid oil',
                                                      as_of: Time.zone.today).to_json

        expect(result).to match_json_expression heading_pattern
      end
    end
  end

  describe '#persisted?' do
    it 'returns false' do
      expect(described_class.new(data_serializer, q: '123')).not_to be_persisted
    end
  end
end
