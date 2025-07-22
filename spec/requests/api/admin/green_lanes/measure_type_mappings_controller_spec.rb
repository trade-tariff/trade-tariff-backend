RSpec.describe Api::Admin::GreenLanes::MeasureTypeMappingsController, :admin do
  subject(:page_response) { make_request && response }

  before do
    allow(TradeTariffBackend).to receive(:service).and_return 'xi'
  end

  let(:json_response) { JSON.parse(page_response.body) }
  let(:mapping) { create :identified_measure_type_category_assessment }

  describe 'GET to #index' do
    let(:make_request) do
      authenticated_get api_admin_green_lanes_measure_type_mappings_path(format: :json)
    end

    context 'with some mappings' do
      before { mapping }

      it { is_expected.to have_http_status :success }
      it { expect(json_response).to include('data') }
      it { expect(json_response['data'].first['type']).to include('green_lanes_measure_type_mapping') }
    end

    context 'without any mappings' do
      it { is_expected.to have_http_status :success }
      it { expect(json_response).to include('data' => []) }
    end
  end

  describe 'GET to #show' do
    let(:make_request) do
      authenticated_get api_admin_green_lanes_measure_type_mapping_path(id, format: :json)
    end

    context 'with existent mapping' do
      let(:id) { mapping.id }

      it { is_expected.to have_http_status :success }
      it { expect(json_response).to include('data') }
    end

    context 'with non-existent mapping' do
      let(:id) { 1001 }

      it { is_expected.to have_http_status :not_found }
    end
  end

  describe 'POST to #create' do
    let(:make_request) do
      authenticated_post api_admin_green_lanes_measure_type_mappings_path(format: :json), params: mapping_data
    end

    let :mapping_data do
      {
        data: {
          type: :green_lanes_measure_type_mapping,
          attributes: ex_attrs,
        },
      }
    end

    context 'with valid params' do
      let(:ex_attrs) { build(:identified_measure_type_category_assessment).to_hash }

      it { is_expected.to have_http_status :created }
      it { expect { page_response }.to change(GreenLanes::IdentifiedMeasureTypeCategoryAssessment, :count).by(1) }
    end

    context 'with invalid params' do
      let(:ex_attrs) { build(:identified_measure_type_category_assessment, theme_id: nil).to_hash }

      it { is_expected.to have_http_status :unprocessable_entity }

      it 'returns errors for mapping' do
        expect(json_response).to include('errors')
      end

      it { expect { page_response }.not_to change(GreenLanes::IdentifiedMeasureTypeCategoryAssessment, :count) }
    end
  end

  describe 'DELETE to #destroy' do
    let :make_request do
      authenticated_delete api_admin_green_lanes_measure_type_mapping_path(id, format: :json)
    end

    context 'with known mapping' do
      let(:id) { mapping.id }

      it { is_expected.to have_http_status :no_content }
      it { expect { page_response }.to change(mapping, :exists?) }
    end

    context 'with unknown mapping' do
      let(:id) { 9999 }

      it { is_expected.to have_http_status :not_found }
      it { expect { page_response }.not_to change(GreenLanes::IdentifiedMeasureTypeCategoryAssessment, :count) }
    end
  end
end
