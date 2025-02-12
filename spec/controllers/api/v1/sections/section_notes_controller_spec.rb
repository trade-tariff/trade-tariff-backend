RSpec.describe Api::V1::Sections::SectionNotesController do
  routes { V1Api.routes }

  let(:pattern) do
    {
      id: Integer,
      section_id: Integer,
      content: String,
    }
  end

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
