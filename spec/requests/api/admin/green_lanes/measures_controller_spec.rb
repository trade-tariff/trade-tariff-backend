RSpec.describe Api::Admin::GreenLanes::MeasuresController, :admin do
  subject(:page_response) { make_request && response }

  before do
    allow(TradeTariffBackend).to receive(:service).and_return 'xi'
  end

  let(:json_response) { JSON.parse(page_response.body) }
  let(:measure) { create :green_lanes_measure }

  describe 'GET to #index' do
    let(:make_request) do
      authenticated_get api_admin_green_lanes_measures_path(format: :json)
    end

    context 'with some measures' do
      before { measure }

      it { is_expected.to have_http_status :success }
      it { expect(json_response).to include('data') }
      it { expect(json_response['data'].first['type']).to include('green_lanes_measure') }
    end

    context 'without any measures' do
      it { is_expected.to have_http_status :success }
      it { expect(json_response).to include('data' => []) }
    end
  end

  describe 'GET to #show' do
    let(:make_request) do
      authenticated_get api_admin_green_lanes_measure_path(id, format: :json)
    end

    context 'with existent measure' do
      let(:id) { measure.id }

      it { is_expected.to have_http_status :success }
      it { expect(json_response).to include('data') }
    end

    context 'with non-existent measure' do
      let(:id) { 1001 }

      it { is_expected.to have_http_status :not_found }
    end
  end

  describe 'POST to #create' do
    let(:make_request) do
      authenticated_post api_admin_green_lanes_measures_path(format: :json), params: measure_data
    end

    let :measure_data do
      {
        data: {
          type: :green_lanes_measure,
          attributes: measure_attrs,
        },
      }
    end

    context 'with valid params' do
      let(:measure_attrs) { build(:green_lanes_measure).to_hash }

      it { is_expected.to have_http_status :created }
      it { expect { page_response }.to change(GreenLanes::Measure, :count).by(1) }
    end

    context 'with invalid params' do
      let(:measure_attrs) { build(:green_lanes_measure, category_assessment_id: nil).to_hash }

      it { is_expected.to have_http_status :unprocessable_content }

      it 'returns errors for exemption' do
        expect(json_response).to include('errors')
      end

      it { expect { page_response }.not_to change(GreenLanes::Measure, :count) }
    end
  end

  describe 'PATCH to #update' do
    let(:new_category_assessment) { create :category_assessment }

    let(:make_request) do
      authenticated_patch api_admin_green_lanes_measure_path(id, format: :json), params: {
        data: {
          type: :green_lanes_measure,
          attributes: { category_assessment_id: new_category_assessment_id },
        },
      }
    end

    context 'with valid params' do
      let(:id) { measure.id }
      let(:new_category_assessment_id) { new_category_assessment.id }

      it { is_expected.to have_http_status :success }
      it { expect { page_response }.not_to change(measure.reload, :productline_suffix) }
    end

    context 'with invalid params' do
      let(:id) { measure.id }
      let(:new_category_assessment_id) { nil }

      it { is_expected.to have_http_status :unprocessable_content }

      it 'returns errors for exemption' do
        expect(json_response).to include('errors')
      end
    end

    context 'with unknown exemption' do
      let(:id) { 9999 }
      let(:new_category_assessment_id) { new_category_assessment.id }

      it { is_expected.to have_http_status :not_found }
      it { expect { page_response }.not_to change(measure.reload, :productline_suffix) }
    end
  end

  describe 'DELETE to #destroy' do
    let :make_request do
      authenticated_delete api_admin_green_lanes_measure_path(id, format: :json)
    end

    context 'with known measure' do
      let(:id) { measure.id }

      it { is_expected.to have_http_status :no_content }
      it { expect { page_response }.to change(measure, :exists?) }
    end

    context 'with unknown measure' do
      let(:id) { 9999 }

      it { is_expected.to have_http_status :not_found }
      it { expect { page_response }.not_to change(GreenLanes::Measure, :count) }
    end
  end
end
