RSpec.describe Api::Admin::Sections::SectionNotesController do
  routes { AdminApi.routes }

  describe 'GET #show' do
    let(:pattern) do
      {
        data: {
          id: String,
          type: 'section_note',
          attributes: {
            section_id: Integer,
            content: String,
          },
        },
      }
    end

    before { login_as_api_user }

    context 'when section note is present' do
      let(:section) { create :section, :with_note }

      it 'returns rendered record' do
        get :show, params: { section_id: section.id }, format: :json

        expect(response.body).to match_json_expression pattern
      end
    end

    context 'when section note is not present' do
      let(:section) { create :section }

      it 'returns not found if record was not found' do
        get :show, params: { section_id: section.id }, format: :json

        expect(response.status).to eq 404
      end
    end
  end

  describe 'POST to #create' do
    let(:section) { create :section }

    before { login_as_api_user }

    context 'when save succeeded' do
      before do
        post :create, params: { section_id: section.id, data: { type: 'section_note', attributes: { content: 'test string' } } }, format: :json
      end

      it 'responds with success' do
        expect(response.status).to eq 201
      end

      it 'returns section_note attributes' do
        pattern = {
          data: {
            id: String,
            type: 'section_note',
            attributes: {
              section_id: Integer,
              content: String,
            },
          },
        }

        expect(response.body).to match_json_expression(pattern)
      end

      it 'persists section note' do
        expect(section.reload.section_note).to be_present
      end
    end

    context 'when save fails' do
      before do
        post :create, params: { section_id: section.id, data: { type: 'section_note', attributes: { content: '' } } }, format: :json
      end

      it 'responds with 422' do
        expect(response.status).to eq 422
      end

      it 'returns section_note validation errors' do
        pattern = {
          errors: [Hash],
        }

        expect(response.body).to match_json_expression(pattern)
      end

      it 'does not persist section note' do
        expect(section.reload.section_note).to be_blank
      end
    end
  end

  describe 'PUT to #update' do
    let(:section) { create :section, :with_note }

    before { login_as_api_user }

    context 'when save succeeded' do
      it 'responds with success' do
        put :update, params: { section_id: section.id, data: { type: 'section_note', attributes: { content: 'test string' } } }, format: :json

        expect(response.status).to eq 200
      end

      it 'changes section_note content' do
        expect {
          put :update, params: { section_id: section.id, data: { type: 'section_note', attributes: { content: 'test string' } } }, format: :json
        }.to(change { section.reload.section_note.content })
      end
    end

    context 'when save fails' do
      it 'responds with 422 not acceptable' do
        put :update, params: { section_id: section.id, data: { type: 'section_note', attributes: { content: '' } } }, format: :json

        expect(response.status).to eq 422
      end

      it 'returns section_note validation errors' do
        put :update, params: { section_id: section.id, data: { type: 'section_note', attributes: { content: '' } } }, format: :json

        pattern = {
          errors: [Hash],
        }

        expect(response.body).to match_json_expression(pattern)
      end

      it 'does not change section_note content' do
        expect {
          put :update, params: { section_id: section.id, section_note: { content: '' } }, format: :json
        }.not_to(change { section.reload.section_note.content })
      end
    end
  end

  describe 'DELETE to #destroy' do
    before { login_as_api_user }

    context 'when deleting succeeds' do
      let(:section) { create :section, :with_note }

      it 'responds with success (204 no content)' do
        delete :destroy, params: { section_id: section.id }, format: :json

        expect(response.status).to eq 204
      end

      it 'deletes section note' do
        expect {
          delete :destroy, params: { section_id: section.id }, format: :json
        }.to(change { section.reload.section_note })
      end
    end

    context 'when deletion fails' do
      let(:section) { create :section }

      it 'responds with 404 not found' do
        delete :destroy, params: { section_id: section.id }, format: :json

        expect(response.status).to eq 404
      end
    end
  end
end
