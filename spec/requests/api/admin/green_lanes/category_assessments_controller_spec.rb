RSpec.describe Api::Admin::GreenLanes::CategoryAssessmentsController, :admin do
  subject(:page_response) { make_request && response }

  before do
    allow(TradeTariffBackend).to receive(:service).and_return 'xi'
  end

  let(:json_response) { JSON.parse(page_response.body) }
  let(:category) { create :category_assessment, :with_green_lanes_measure, :with_exemption }

  shared_examples_for 'search category assessment response' do
    it { is_expected.to have_http_status :success }
    it { expect(json_response).to include('data') }
    it { expect(json_response).to include('meta') }

    it 'expects measure_type_id to be in the json response' do
      measure_type_ids = json_response['data'].map { |item| item['attributes']['measure_type_id'] }
      expect(measure_type_ids).to include(category.measure_type_id.to_s)
    end
  end

  describe 'GET to #index search' do
    before do
      category
    end

    let(:make_request) do
      authenticated_get api_admin_green_lanes_category_assessments_path(format: :json), params: search_data
    end

    context 'with some category assessments, search by exemption code' do
      let :search_data do
        {
          query: {
            exemption_code: category.exemptions[1].code,
            page: 1,
          },
        }
      end

      it_behaves_like 'search category assessment response'
    end

    context 'with some category assessments, search by measure type id' do
      let :search_data do
        {
          query: {
            measure_type_id: category.measure_type_id.to_s,
            page: 1,
          },
        }
      end

      it_behaves_like 'search category assessment response'
    end

    context 'with some category assessments, search by regulation id' do
      let :search_data do
        {
          query: {
            regulation_id: category.regulation_id.to_s,
            page: 1,
          },
        }
      end

      it_behaves_like 'search category assessment response'
    end

    context 'with some category assessments, search by regulation role' do
      let :search_data do
        {
          query: {
            regulation_role: category.regulation_role,
            page: 1,
          },
        }
      end

      it_behaves_like 'search category assessment response'
    end

    context 'with some category assessments, search by theme id' do
      let :search_data do
        {
          query: {
            theme_id: category.theme_id.to_s,
            page: 1,
          },
        }
      end

      it_behaves_like 'search category assessment response'
    end

    context 'with some category assessments, sort by parameter present' do
      let :search_data do
        {
          query: {
            sort: 'regulation_id',
            direction: 'desc',
            page: 1,
          },
        }
      end

      let :regulation_ids do
        json_response['data'].map { |assessment| assessment['attributes']['regulation_id'] }
      end

      it { is_expected.to have_http_status :success }

      it { expect(regulation_ids).to eq(regulation_ids.sort.reverse) }
    end
  end

  describe 'GET to #index' do
    let(:make_request) do
      authenticated_get api_admin_green_lanes_category_assessments_path(format: :json)
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
      authenticated_get api_admin_green_lanes_category_assessment_path(id, format: :json)
    end

    context 'with existent category assessment' do
      let(:id) { category.id }

      it { is_expected.to have_http_status :success }
      it { expect(json_response).to include('data') }

      it 'only contains green_lanes_measure or green_lanes_exemption types' do
        json_response['included'].each do |json_object|
          expect(json_object['type']).to(satisfy { |type| %w[green_lanes_measure green_lanes_exemption green_lanes_goods_nomenclature].include?(type) })
        end
      end
    end

    context 'with non-existent category assessments item' do
      let(:id) { 1001 }

      it { is_expected.to have_http_status :not_found }
    end
  end

  describe 'POST to #create' do
    let(:make_request) do
      authenticated_post api_admin_green_lanes_category_assessments_path(format: :json), params: ca_data
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
      it { expect { page_response }.to change(GreenLanes::CategoryAssessment, :count).by(1) }
    end

    context 'with invalid params' do
      let(:ca_attrs) { build(:category_assessment, regulation_role: nil).to_hash }

      it { is_expected.to have_http_status :unprocessable_content }

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
      authenticated_patch api_admin_green_lanes_category_assessment_path(id, format: :json), params: {
        data: {
          type: :category_assessment,
          attributes: { regulation_role: updated_regulation },
        },
      }
    end

    context 'with valid params' do
      it { is_expected.to have_http_status :success }
      it { expect { page_response }.not_to change(category.reload, :regulation_role) }
    end

    context 'with invalid params' do
      let(:updated_regulation) { nil }

      it { is_expected.to have_http_status :unprocessable_content }

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

  describe 'POST to #add_exemption' do
    let(:exemption) { create :green_lanes_exemption }

    let(:id) { category.id }
    let(:exemption_id) { exemption.id }

    let(:make_request) do
      authenticated_post exemptions_api_admin_green_lanes_category_assessment_path(id, format: :json), params: {
        id:,
        exemption_id:,
      }
    end

    context 'with valid params' do
      it { is_expected.to have_http_status :success }
      it { expect { page_response }.not_to change(category.reload, :regulation_role) }
    end

    context 'with unknown exemption' do
      let(:exemption_id) { 9999 }

      it { is_expected.to have_http_status :not_found }
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
      authenticated_delete api_admin_green_lanes_category_assessment_path(id, format: :json)
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
