RSpec.describe Api::Admin::TariffKnowledgeCompressedNotesController do
  describe '#index' do
    before do
      create(:tariff_knowledge_compressed_note, goods_nomenclature_sid: 123, goods_nomenclature_item_id: '0101210000', needs_review: true, approved: false)
      create(:tariff_knowledge_compressed_note, goods_nomenclature_sid: 456, goods_nomenclature_item_id: '0101290000', needs_review: false, approved: true)
      create(:tariff_knowledge_compressed_note, goods_nomenclature_sid: 789, goods_nomenclature_item_id: '0201100000', needs_review: true, expired: true)
    end

    it 'lists non-approved current compressed notes by default' do
      get '/uk/admin/tariff_knowledge_compressed_notes.json', headers: request_headers(format: :json)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['data'].map { |record| record['id'] }).to eq(%w[123])
      expect(response.parsed_body.dig('meta', 'pagination', 'total_count')).to eq(1)
    end

    it 'can list expired compressed notes' do
      get '/uk/admin/tariff_knowledge_compressed_notes.json', params: { status: 'expired' }, headers: request_headers(format: :json)

      expect(response.parsed_body['data'].map { |record| record['id'] }).to eq(%w[789])
    end
  end
end
