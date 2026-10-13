RSpec.describe Search::ResultAncestors do
  describe '.attach' do
    let(:chapter) do
      create(:chapter, :with_description,
             goods_nomenclature_item_id: '0100000000',
             description: 'Live animals')
    end
    let(:heading) do
      create(:heading, :with_description,
             goods_nomenclature_item_id: '0101000000',
             description: 'Live horses')
    end

    def result_for(item_id, sid, klass: 'Commodity', score: 1.0)
      GoodsNomenclatureResult.new(
        id: sid,
        goods_nomenclature_sid: sid,
        goods_nomenclature_item_id: item_id,
        producline_suffix: '80',
        goods_nomenclature_class: klass,
        description: 'result',
        formatted_description: 'Result',
        self_text: nil,
        classification_description: 'Result',
        full_description: 'Result',
        heading_description: nil,
        declarable: true,
        score:,
        confidence: nil,
      )
    end

    before { chapter && heading }

    context 'with commodity results' do
      subject(:attached) { described_class.attach(response, as_of: Time.zone.today) }

      let(:results) { [result_for('0101210000', 1, score: 6.0)] }
      let(:response) { Api::Internal::GoodsNomenclatureSearchSerializer.serialize(results) }

      it 'enriches primary items with heading and chapter relationships', :aggregate_failures do
        expect(attached[:data].first[:relationships]).to eq(
          heading: { data: { type: :heading, id: heading.goods_nomenclature_sid.to_s } },
          chapter: { data: { type: :chapter, id: chapter.goods_nomenclature_sid.to_s } },
        )
      end

      it 'adds heading and chapter resources to included with display descriptions', :aggregate_failures do
        expect(attached[:included]).to contain_exactly(
          hash_including(
            id: heading.goods_nomenclature_sid.to_s,
            type: :heading,
            attributes: hash_including(
              goods_nomenclature_item_id: '0101000000',
              description: 'Live horses',
              formatted_description: 'Live horses',
            ),
            relationships: { chapter: { data: { type: :chapter, id: chapter.goods_nomenclature_sid.to_s } } },
          ),
          hash_including(
            id: chapter.goods_nomenclature_sid.to_s,
            type: :chapter,
            attributes: hash_including(
              goods_nomenclature_item_id: '0100000000',
              description: 'Live animals',
              formatted_description: 'Live animals',
            ),
          ),
        )
      end

      it 'does not expose declarable on ancestor resources' do
        expect(attached[:included].map { |resource| resource[:attributes].key?(:declarable) }).to all(be_falsey)
      end

      it 'preserves primary ranking attributes and order', :aggregate_failures do
        expect(attached[:data].map { |item| item[:attributes][:goods_nomenclature_item_id] })
          .to eq(%w[0101210000])
        expect(attached[:data].first[:attributes][:score]).to eq(6.0)
      end
    end

    context 'with results sharing ancestors' do
      let(:results) do
        [
          result_for('0101210001', 1, score: 9.0),
          result_for('0101210002', 2, score: 8.0),
          result_for('0101290001', 3, score: 7.0),
        ]
      end
      let(:response) { Api::Internal::GoodsNomenclatureSearchSerializer.serialize(results) }

      it 'dedupes shared ancestors into one included copy', :aggregate_failures do
        attached = described_class.attach(response, as_of: Time.zone.today)

        expect(attached[:included].map { |resource| resource[:type] }).to contain_exactly(:heading, :chapter)
        expect(attached[:data]).to all(have_key(:relationships))
      end
    end

    context 'with heading and chapter primary resources' do
      let(:results) do
        [
          result_for('0100000000', chapter.goods_nomenclature_sid, klass: 'Chapter', score: 10.0),
          result_for('0101000000', heading.goods_nomenclature_sid, klass: 'Heading', score: 8.0),
          result_for('0101210000', 3, score: 6.0),
        ]
      end
      let(:response) { Api::Internal::GoodsNomenclatureSearchSerializer.serialize(results) }

      it 'does not repeat primary identities in included', :aggregate_failures do
        attached = described_class.attach(response, as_of: Time.zone.today)

        included_keys = (attached[:included] || []).map { |resource| [resource[:type].to_s, resource[:id].to_s] }

        expect(included_keys).to be_empty
        expect(attached[:data].length).to eq(3)
      end

      it 'enriches the chapter linkage on the primary heading', :aggregate_failures do
        attached = described_class.attach(response, as_of: Time.zone.today)

        primary_heading = attached[:data].find { |item| item[:type] == :heading }
        primary_chapter = attached[:data].find { |item| item[:type] == :chapter }

        expect(primary_heading[:relationships]).to eq(
          chapter: { data: { type: :chapter, id: chapter.goods_nomenclature_sid.to_s } },
        )
        expect(primary_chapter).not_to have_key(:relationships)
        expect(primary_heading[:relationships][:chapter][:data][:id]).to eq(primary_chapter[:id])
      end

      it 'links the primary commodity to the primary heading and chapter', :aggregate_failures do
        attached = described_class.attach(response, as_of: Time.zone.today)

        primary_commodity = attached[:data].find { |item| item[:type] == :commodity }
        primary_keys = attached[:data].map { |item| [item[:type].to_s, item[:id].to_s] }

        linked_resources = %i[heading chapter].map do |type|
          linkage = primary_commodity.dig(:relationships, type, :data)
          [linkage[:type].to_s, linkage[:id]]
        end

        expect(linked_resources).to all(be_in(primary_keys))
        expect(primary_commodity[:relationships][:heading][:data][:id]).to eq(heading.goods_nomenclature_sid.to_s)
        expect(primary_commodity[:relationships][:chapter][:data][:id]).to eq(chapter.goods_nomenclature_sid.to_s)
      end
    end

    context 'with hidden ancestors' do
      before do
        create(:hidden_goods_nomenclature, goods_nomenclature_item_id: '0101000000')
      end

      let(:results) { [result_for('0101210000', 1)] }
      let(:response) { Api::Internal::GoodsNomenclatureSearchSerializer.serialize(results) }

      it 'omits hidden ancestors while keeping visible ones', :aggregate_failures do
        attached = described_class.attach(response, as_of: Time.zone.today)

        expect(attached[:data].first[:relationships]).to eq(
          chapter: { data: { type: :chapter, id: chapter.goods_nomenclature_sid.to_s } },
        )
        expect(attached[:included]).to contain_exactly(
          hash_including(type: :chapter),
        )
      end
    end

    context 'with ancestors not valid at the as_of date' do
      let(:heading) do
        create(:heading, :with_description,
               goods_nomenclature_item_id: '0101000000',
               validity_start_date: Date.tomorrow,
               description: 'Live horses')
      end

      let(:results) { [result_for('0101210000', 1)] }
      let(:response) { Api::Internal::GoodsNomenclatureSearchSerializer.serialize(results) }

      it 'omits ancestors outside their validity range', :aggregate_failures do
        attached = described_class.attach(response, as_of: Time.zone.today)

        expect(attached[:data].first[:relationships]).to eq(
          chapter: { data: { type: :chapter, id: chapter.goods_nomenclature_sid.to_s } },
        )
      end
    end

    context 'with no loadable ancestors' do
      let(:results) { [result_for('9905000000', 1)] }
      let(:response) { Api::Internal::GoodsNomenclatureSearchSerializer.serialize(results) }

      it 'leaves the response unchanged', :aggregate_failures do
        attached = described_class.attach(response, as_of: Time.zone.today)

        expect(attached).to equal(response)
        expect(attached).not_to have_key(:included)
        expect(attached[:data].first).not_to have_key(:relationships)
      end
    end

    context 'with empty results' do
      let(:response) { { data: [] } }

      it 'returns the response unchanged' do
        expect(described_class.attach(response, as_of: Time.zone.today)).to equal(response)
      end
    end

    context 'with bounded query counts' do
      def attach_query_count(results)
        response = Api::Internal::GoodsNomenclatureSearchSerializer.serialize(results)
        ::SequelRails::Railties::LogSubscriber.reset_count

        described_class.attach(response, as_of: Time.zone.today)

        ::SequelRails::Railties::LogSubscriber.count
      end

      it 'runs the same number of queries as distinct ancestors increase' do
        %w[02 03].each do |code|
          create(:chapter, :with_description, goods_nomenclature_item_id: "#{code}00000000")
          create(:heading, :with_description, goods_nomenclature_item_id: "#{code}01000000")
        end
        one = [result_for('0101210001', 1)]
        many = one + [result_for('0201210001', 2), result_for('0301210001', 3)]

        single_result_queries = attach_query_count(one)
        many_result_queries = attach_query_count(many)

        expect(single_result_queries).to be_positive
        expect(many_result_queries).to eq(single_result_queries)
      end
    end
  end
end
