RSpec.describe Api::V1::Chapters::ChapterNotesController, 'GET #show' do
  render_views

  let(:pattern) do
    {
      id: Integer,
      section_id: nil,
      chapter_id: String,
      content: String,
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

RSpec.describe Api::V1::Chapters::ChapterNotesController, 'POST to #create' do
  let(:chapter) { create :chapter }

  before { login_as_api_user }

  context 'save succeeded' do
    before do
      post :create, params: { chapter_id: chapter.to_param, chapter_note: { content: 'test string' } }, format: :json
    end

    it 'responds with success' do
      expect(response.status).to eq 201
    end

    it 'returns chapter_note attributes' do
      pattern = {
        id: Integer,
        chapter_id: String,
        section_id: nil,
        content: String,
      }

      expect(response.body).to match_json_expression(pattern)
    end

    it 'persists chapter note' do
      expect(chapter.reload.chapter_note).to be_present
    end
  end

  context 'save failed' do
    before do
      post :create, params: { chapter_id: chapter.to_param, chapter_note: { content: '' } }, format: :json
    end

    it 'responds with 422' do
      expect(response.status).to eq 422
    end

    it 'returns chapter_note validation errors' do
      pattern = {
        errors: Hash,
      }

      expect(response.body).to match_json_expression(pattern)
    end

    it 'does not persist chapter note' do
      expect(chapter.reload.chapter_note).to be_blank
    end
  end
end

RSpec.describe Api::V1::Chapters::ChapterNotesController, 'PUT to #update' do
  let(:chapter) { create :chapter, :with_note }

  before { login_as_api_user }

  context 'save succeeded' do
    it 'responds with success (204 no content)' do
      put :update, params: {  chapter_id: chapter.to_param, chapter_note: { content: 'test string' } }, format: :json

      expect(response.status).to eq 204
    end

    it 'changes chapter_note content' do
      expect {
        put :update, params: { chapter_id: chapter.to_param, chapter_note: { content: 'test string' } }, format: :json
      }.to change { chapter.reload.chapter_note.content }
    end
  end

  context 'save failed' do
    it 'responds with 422 not acceptable' do
      put :update, params: { chapter_id: chapter.to_param, chapter_note: { content: '' } }, format: :json

      expect(response.status).to eq 422
    end

    it 'returns chapter_note validation errors' do
      put :update, params: { chapter_id: chapter.to_param, chapter_note: { content: '' } }, format: :json

      pattern = {
        errors: Hash,
      }

      expect(response.body).to match_json_expression(pattern)
    end

    it 'does not change chapter_note content' do
      expect {
        put :update, params: { chapter_id: chapter.to_param, chapter_note: { content: '' } }, format: :json
      }.not_to change { chapter.reload.chapter_note.content }
    end
  end
end

RSpec.describe Api::V1::Chapters::ChapterNotesController, 'DELETE to #destroy' do
  before { login_as_api_user }

  context 'deletiong succeeded' do
    let(:chapter) { create :chapter, :with_note }

    it 'responds with success (204 no content)' do
      delete :destroy, params: { chapter_id: chapter.to_param }, format: :json

      expect(response.status).to eq 204
    end

    it 'deletes chapter note' do
      expect {
        delete :destroy, params: { chapter_id: chapter.to_param }, format: :json
      }.to change { chapter.reload.chapter_note }
    end
  end

  context 'deletion failed' do
    let(:chapter) { create :chapter }

    it 'responds with 404 not found' do
      delete :destroy, params: { chapter_id: chapter.to_param }, format: :json

      expect(response.status).to eq 404
    end
  end
end
