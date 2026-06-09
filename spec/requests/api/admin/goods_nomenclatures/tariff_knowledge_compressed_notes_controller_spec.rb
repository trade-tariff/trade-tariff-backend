RSpec.describe Api::Admin::GoodsNomenclatures::TariffKnowledgeCompressedNotesController do
  let!(:note) do
    create(
      :tariff_knowledge_compressed_note,
      goods_nomenclature_sid: 123,
      goods_nomenclature_item_id: '0101210000',
      content: 'Heading 0101 covers live horses.',
      needs_review: true,
      approved: false,
    )
  end

  describe '#show' do
    it 'returns compressed note review content' do
      get '/uk/admin/goods_nomenclatures/123/tariff_knowledge_compressed_note.json', headers: request_headers(format: :json)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig('data', 'attributes')).to include(
        'goods_nomenclature_sid' => 123,
        'goods_nomenclature_item_id' => '0101210000',
        'content' => 'Heading 0101 covers live horses.',
        'needs_review' => true,
      )
    end
  end

  describe '#update' do
    it 'applies a manual edit' do
      put '/uk/admin/goods_nomenclatures/123/tariff_knowledge_compressed_note.json',
          params: { data: { type: 'tariff_knowledge_compressed_note', attributes: { content: 'Reviewed note' } } },
          headers: request_headers(format: :json),
          as: :json

      expect(response).to have_http_status(:ok)
      expect(note.reload).to have_attributes(
        content: 'Reviewed note',
        manually_edited: true,
        approved: true,
        needs_review: false,
      )
    end
  end

  describe '#approve' do
    it 'approves the compressed note' do
      post '/uk/admin/goods_nomenclatures/123/tariff_knowledge_compressed_note/approve.json', headers: request_headers(format: :json), as: :json

      expect(response).to have_http_status(:ok)
      expect(note.reload).to have_attributes(approved: true, needs_review: false)
    end
  end

  describe '#reject' do
    it 'marks the compressed note as needing review' do
      note.update(approved: true, needs_review: false)

      post '/uk/admin/goods_nomenclatures/123/tariff_knowledge_compressed_note/reject.json', headers: request_headers(format: :json), as: :json

      expect(response).to have_http_status(:ok)
      expect(note.reload).to have_attributes(approved: false, needs_review: true)
    end
  end

  describe '#versions' do
    it 'returns compressed note versions' do
      note.update(content: 'Changed note')

      get '/uk/admin/goods_nomenclatures/123/tariff_knowledge_compressed_note/versions.json', headers: request_headers(format: :json)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['data'].first['type']).to eq('version')
    end
  end

  describe '#regenerate' do
    it 'delegates regeneration for this goods nomenclature sid' do
      allow(TariffKnowledge::CompressedNoteGenerator).to receive(:call) do
        note.update(content: 'Regenerated note')
      end

      post '/uk/admin/goods_nomenclatures/123/tariff_knowledge_compressed_note/regenerate.json', headers: request_headers(format: :json), as: :json

      expect(response).to have_http_status(:ok)
      expect(TariffKnowledge::CompressedNoteGenerator)
        .to have_received(:call).with(goods_nomenclature_sids: [123])
      expect(response.parsed_body.dig('data', 'attributes', 'content')).to eq('Regenerated note')
    end
  end
end
