RSpec.describe Api::Admin::Chapters::ChapterNotesController do
  routes { AdminApi.routes }

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

    before { login_as_api_user }

    context 'when chapter note is present' do
      let(:chapter) { create :chapter, :with_note }

      it 'returns rendered record' do
        get :show, params: { chapter_id: chapter.to_param }, format: :json

        expect(response.body).to match_json_expression pattern
      end
    end

    context 'when chapter note is not present' do
      let(:chapter) { create :chapter }

      it 'returns not found if record was not found' do
        get :show, params: { chapter_id: chapter.to_param }, format: :json

        expect(response.status).to eq 404
      end
    end
  end

  describe '#create' do
    let(:chapter) { create :chapter }

    before { login_as_api_user }

    context 'when save succeeded' do
      before do
        post :create, params: { chapter_id: chapter.to_param, data: { type: 'chapter_note', attributes: { content: 'test string' } } }, format: :json
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
        post :create, params: { chapter_id: chapter.to_param, data: { type: 'chapter_note', attributes: { content: '' } } }, format: :json
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

    before { login_as_api_user }

    context 'when save succeeded' do
      it 'responds with success' do
        put :update, params: { chapter_id: chapter.to_param, data: { type: 'chapter_note', attributes: { content: 'test string' } } }, format: :json

        expect(response.status).to eq 200
      end

      it 'changes chapter_note content' do
        expect {
          put :update, params: { chapter_id: chapter.to_param, data: { type: 'chapter_note', attributes: { content: 'test string' } } }, format: :json
        }.to(change { chapter.reload.chapter_note.content })
      end
    end

    context 'when save failed' do
      it 'responds with 422 not acceptable' do
        put :update, params: { chapter_id: chapter.to_param, data: { type: 'chapter_note', attributes: { content: '' } } }, format: :json

        expect(response.status).to eq 422
      end

      it 'returns chapter_note validation errors' do
        put :update, params: { chapter_id: chapter.to_param, data: { type: 'chapter_note', attributes: { content: '' } } }, format: :json

        pattern = {
          errors: [Hash],
        }

        expect(response.body).to match_json_expression(pattern)
      end

      it 'does not change chapter_note content' do
        expect {
          put :update, params: { chapter_id: chapter.to_param, data: { type: 'chapter_note', attributes: { content: '' } } }, format: :json
        }.not_to(change { chapter.reload.chapter_note.content })
      end
    end
  end

  describe '#destroy' do
    before { login_as_api_user }

    context 'when deletiong succeeded' do
      let(:chapter) { create :chapter, :with_note }

      it 'responds with success (204 no content)' do
        delete :destroy, params: { chapter_id: chapter.to_param }, format: :json

        expect(response.status).to eq 204
      end

      it 'deletes chapter note' do
        expect {
          delete :destroy, params: { chapter_id: chapter.to_param }, format: :json
        }.to(change { chapter.reload.chapter_note })
      end
    end

    context 'when deletion failed' do
      let(:chapter) { create :chapter }

      it 'responds with 404 not found' do
        delete :destroy, params: { chapter_id: chapter.to_param }, format: :json

        expect(response.status).to eq 404
      end
    end
  end
end
