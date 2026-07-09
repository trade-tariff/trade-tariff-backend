RSpec.describe 'Knowledge graph queries API' do
  describe 'POST /knowledge_graph/queries' do
    subject(:make_request) do
      post '/uk/api/knowledge_graph/queries',
           params: params,
           headers: request_headers(version: 2),
           as: :json
    end

    let(:goods_node) do
      create(:tariff_knowledge_node, goods_nomenclature_item_id: '0101210000', goods_nomenclature_sid: 123)
    end

    let(:fragment) do
      create(
        :tariff_knowledge_node,
        :note_fragment,
        key: 'note_fragment:chapter-01:1',
        title: 'Chapter 01 note 1',
        content: 'This chapter covers live horses.',
        source_type: 'customs_tariff_chapter_note',
        source_id: '01',
      )
    end

    let(:range_node) do
      create(
        :tariff_knowledge_node,
        node_type: TariffKnowledge::Node::RANGE,
        key: 'range:0101',
        title: '0101',
        content: 'Heading 0101',
        goods_nomenclature_sid: nil,
        goods_nomenclature_item_id: nil,
        producline_suffix: nil,
        goods_nomenclature_type: nil,
      )
    end

    let(:params) do
      {
        data: {
          type: 'knowledge_graph_query',
          attributes: {
            preset: 'note_mentions',
            subjects: [
              {
                type: 'goods_nomenclature',
                identifiers: {
                  goods_nomenclature_sid: 123,
                },
              },
            ],
            include: %w[nodes edges],
          },
        },
      }
    end

    before do
      create(:tariff_knowledge_edge, source_node: fragment, target_node: goods_node, relationship_type: TariffKnowledge::Edge::APPLIES_TO)
      create(:tariff_knowledge_edge, source_node: fragment, target_node: range_node, relationship_type: TariffKnowledge::Edge::REFERENCES)
      create(:tariff_knowledge_edge, source_node: range_node, target_node: goods_node, relationship_type: TariffKnowledge::Edge::EXPANDS_TO)
    end

    it 'returns graph nodes and edges for the note mentions preset' do
      make_request

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)

      expect(body).to include(
        'data' => include(
          include(
            'type' => 'knowledge_graph_node',
            'id' => 'note_fragment:chapter-01:1',
            'attributes' => include(
              'node_type' => 'note_fragment',
              'key' => 'note_fragment:chapter-01:1',
              'content' => 'This chapter covers live horses.',
            ),
          ),
        ),
        'included' => include(
          include(
            'type' => 'knowledge_graph_edge',
            'attributes' => include('relationship_type' => 'applies_to'),
          ),
          include(
            'type' => 'knowledge_graph_edge',
            'attributes' => include('relationship_type' => 'expands_to'),
          ),
          include(
            'type' => 'knowledge_graph_node',
            'id' => 'range:0101',
            'attributes' => include('node_type' => 'range', 'title' => '0101'),
          ),
        ),
        'meta' => include(
          'subject_count' => 1,
          'result_count' => 1,
          'truncated' => false,
        ),
      )
    end

    context 'with an over-limit depth' do
      let(:params) do
        {
          data: {
            type: 'knowledge_graph_query',
            attributes: {
              subjects: [{ node_key: 'goods_nomenclature:123' }],
              traversals: [{ edge_type: 'applies_to', direction: 'incoming', max_depth: 4 }],
            },
          },
        }
      end

      it 'returns a validation error' do
        make_request

        expect(response).to have_http_status(:unprocessable_content)
        expect(JSON.parse(response.body)).to include(
          'errors' => include(
            include(
              'title' => 'Invalid knowledge graph query',
              'detail' => 'max_depth must be less than or equal to 3',
              'source' => include('pointer' => '/data/attributes/traversals/0/max_depth'),
            ),
          ),
        )
      end
    end
  end
end
