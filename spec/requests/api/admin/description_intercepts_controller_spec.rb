RSpec.describe Api::Admin::DescriptionInterceptsController, :admin, type: :request do
  describe 'DELETE #destroy' do
    let!(:intercept) { create(:description_intercept, term: 'footwear') }

    it 'deletes the description intercept' do
      expect {
        authenticated_delete api_admin_description_intercept_path(intercept.id, format: :json)
      }.to change(DescriptionIntercept, :count).by(-1)

      expect(response).to have_http_status(:no_content)
    end

    it 'returns 404 when not found' do
      authenticated_delete api_admin_description_intercept_path(999_999, format: :json)

      expect(response).to have_http_status(:not_found)
    end
  end
end
