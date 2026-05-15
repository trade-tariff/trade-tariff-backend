RSpec.describe Api::Admin::Chapters::ChapterNotesController do
  describe '#show' do
    let(:pattern) do
      {
        data: {
          id: String,
          type: 'chapter_note',
          attributes: {
            section_id: nil,
            chapter_id: String,
            content: String,
          },
        },
      }
    end

    context 'when chapter note is present' do
      let(:chapter) { create :chapter, :with_note }

      it 'returns api_response record' do
        get "/uk/admin/chapters/#{chapter.to_param}/chapter_note.json", headers: request_headers(format: :json)

        expect(response.body).to match_json_expression pattern
      end
    end

    context 'when chapter note is not present' do
      let(:chapter) { create :chapter }

      it 'returns not found if record was not found' do
        get "/uk/admin/chapters/#{chapter.to_param}/chapter_note.json", headers: request_headers(format: :json)

        expect(response.status).to eq 404
      end
    end
  end

  describe '#create' do
    let(:chapter) { create :chapter }

    context 'when save succeeded' do
      before do
        post "/uk/admin/chapters/#{chapter.to_param}/chapter_note.json", params: { data: { type: 'chapter_note', attributes: { content: 'test string' } } }, headers: request_headers(format: :json), as: :json
      end

      it 'responds with success' do
        expect(response.status).to eq 201
      end

      it 'returns chapter_note attributes' do
        pattern = {
          data: {
            id: String,
            type: 'chapter_note',
            attributes: {
              section_id: nil,
              chapter_id: String,
              content: String,
            },
          },
        }

        expect(response.body).to match_json_expression(pattern)
      end

      it 'persists chapter note' do
        expect(chapter.reload.chapter_note).to be_present
      end
    end

    context 'when save failed' do
      before do
        post "/uk/admin/chapters/#{chapter.to_param}/chapter_note.json", params: { data: { type: 'chapter_note', attributes: { content: '' } } }, headers: request_headers(format: :json), as: :json
      end

      it 'responds with 422' do
        expect(response.status).to eq 422
      end

      it 'returns chapter_note validation errors' do
        pattern = {
          errors: [Hash],
        }

        expect(response.body).to match_json_expression(pattern)
      end

      it 'does not persist chapter note' do
        expect(chapter.reload.chapter_note).to be_blank
      end
    end
  end

  describe '#update' do
    let(:chapter) { create :chapter, :with_note }

    context 'when save succeeded' do
      it 'responds with success' do
        put "/uk/admin/chapters/#{chapter.to_param}/chapter_note.json", params: { data: { type: 'chapter_note', attributes: { content: 'test string' } } }, headers: request_headers(format: :json), as: :json

        expect(response.status).to eq 200
      end

      it 'changes chapter_note content' do
        expect {
          put "/uk/admin/chapters/#{chapter.to_param}/chapter_note.json", params: { data: { type: 'chapter_note', attributes: { content: 'test string' } } }, headers: request_headers(format: :json), as: :json
        }.to(change { chapter.reload.chapter_note.content })
      end
    end

    context 'when save failed' do
      it 'responds with 422 not acceptable' do
        put "/uk/admin/chapters/#{chapter.to_param}/chapter_note.json", params: { data: { type: 'chapter_note', attributes: { content: '' } } }, headers: request_headers(format: :json), as: :json

        expect(response.status).to eq 422
      end

      it 'returns chapter_note validation errors' do
        put "/uk/admin/chapters/#{chapter.to_param}/chapter_note.json", params: { data: { type: 'chapter_note', attributes: { content: '' } } }, headers: request_headers(format: :json), as: :json

        pattern = {
          errors: [Hash],
        }

        expect(response.body).to match_json_expression(pattern)
      end

      it 'does not change chapter_note content' do
        expect {
          put "/uk/admin/chapters/#{chapter.to_param}/chapter_note.json", params: { data: { type: 'chapter_note', attributes: { content: '' } } }, headers: request_headers(format: :json), as: :json
        }.not_to(change { chapter.reload.chapter_note.content })
      end
    end
  end

  describe '#destroy' do
    context 'when deletiong succeeded' do
      let(:chapter) { create :chapter, :with_note }

      it 'responds with success (204 no content)' do
        delete "/uk/admin/chapters/#{chapter.to_param}/chapter_note.json", headers: request_headers(format: :json), as: :json

        expect(response.status).to eq 204
      end

      it 'deletes chapter note' do
        expect {
          delete "/uk/admin/chapters/#{chapter.to_param}/chapter_note.json", headers: request_headers(format: :json), as: :json
        }.to(change { chapter.reload.chapter_note })
      end
    end

    context 'when deletion failed' do
      let(:chapter) { create :chapter }

      it 'responds with 404 not found' do
        delete "/uk/admin/chapters/#{chapter.to_param}/chapter_note.json", headers: request_headers(format: :json), as: :json

        expect(response.status).to eq 404
      end
    end
  end
end
