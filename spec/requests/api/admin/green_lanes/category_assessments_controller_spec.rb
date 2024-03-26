RSpec.describe Api::Admin::GreenLanes::CategoryAssessmentsController do
  subject(:page_response) { make_request && response }

  before do
    allow(TradeTariffBackend).to receive(:service).and_return 'xi'
  end

  let(:json_response) { JSON.parse(page_response.body) }
  let(:category) { create :category_assessment }

  describe 'GET to #index' do
    let(:make_request) do
      authenticated_get api_admin_category_assessments_path(format: :json)
    end

    context 'with some category assessments' do
      before do
        category
      end

      it { is_expected.to have_http_status :success }
      it { expect(json_response).to include('data') }
      it { expect(json_response).to include('meta') }
    end

    context 'without any category assessments' do
      it { is_expected.to have_http_status :success }
      it { expect(json_response).to include('data' => []) }
    end
  end

  describe 'GET to #show' do
    let(:make_request) do
      authenticated_get api_admin_category_assessment_path(id, format: :json)
    end

    context 'with existent category assessment' do
      let(:id) { category.id }

      it { is_expected.to have_http_status :success }
      it { expect(json_response).to include('data') }
    end

    context 'with non-existent category assessments item' do
      let(:id) { 1001 }

      it { is_expected.to have_http_status :not_found }
    end
  end

  describe 'POST to #create' do
    let(:make_request) do
      authenticated_post api_admin_category_assessments_path(format: :json), params: ca_data
    end

    let :ca_data do
      {
        data: {
          type: :category_assessment,
          attributes: ca_attrs,
        },
      }
    end

    context 'with valid params' do
      let(:ca_attrs) { build(:category_assessment).to_hash }

      it { is_expected.to have_http_status :created }
      it { is_expected.to have_attributes location: api_admin_category_assessment_url(GreenLanes::CategoryAssessment.last.id) }
      it { expect { page_response }.to change(GreenLanes::CategoryAssessment, :count).by(1) }
    end

    context 'with invalid params' do
      let(:ca_attrs) { build(:category_assessment, regulation_role: nil).to_hash }

      it { is_expected.to have_http_status :unprocessable_entity }

      it 'returns errors for category assessment' do
        expect(json_response).to include('errors')
      end

      it { expect { page_response }.not_to change(GreenLanes::CategoryAssessment, :count) }
    end
  end

  describe 'PATCH to #update' do
    let(:id) { category.id }
    let(:updated_regulation) { '3' }

    let(:make_request) do
      authenticated_patch api_admin_category_assessment_path(id, format: :json), params: {
        data: {
          type: :category_assessment,
          attributes: { regulation_role: updated_regulation },
        },
      }
    end

    context 'with valid params' do
      it { is_expected.to have_http_status :success }
      it { is_expected.to have_attributes location: api_admin_category_assessment_url(category.id) }
      it { expect { page_response }.not_to change(category.reload, :regulation_role) }
    end

    context 'with invalid params' do
      let(:updated_regulation) { nil }

      it { is_expected.to have_http_status :unprocessable_entity }

      it 'returns errors for category assessment' do
        expect(json_response).to include('errors')
      end

      it { expect { page_response }.not_to change(category.reload, :regulation_role) }
    end

    context 'with unknown category assessment' do
      let(:id) { 9999 }

      it { is_expected.to have_http_status :not_found }
      it { expect { page_response }.not_to change(category.reload, :regulation_role) }
    end
  end

  describe 'DELETE to #destroy' do
    let :make_request do
      authenticated_delete api_admin_category_assessment_path(id, format: :json)
    end

    context 'with known category assessment' do
      let(:id) { category.id }

      it { is_expected.to have_http_status :no_content }
      it { expect { page_response }.to change(category, :exists?) }
    end

    context 'with unknown category assessment' do
      let(:id) { 9999 }

      it { is_expected.to have_http_status :not_found }
      it { expect { page_response }.not_to change(GreenLanes::CategoryAssessment, :count) }
    end
  end
end
