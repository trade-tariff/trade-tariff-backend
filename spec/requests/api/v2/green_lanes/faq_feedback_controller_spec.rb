RSpec.describe Api::V2::GreenLanes::FaqFeedbackController, :v2 do
  subject(:api_response) { make_request && response }

  let(:json_response) { JSON.parse(api_response.body) }
  let(:faq_feedback) { create :green_lanes_faq_feedback }
  let :authorization do
    ActionController::HttpAuthentication::Token.encode_credentials('Trade-Tariff-Test')
  end

  before do
    allow(TradeTariffBackend).to receive_messages(
      green_lanes_api_tokens: 'Trade-Tariff-Test',
      uk?: false,
    )
  end

  describe 'POST to #create' do
    let(:make_request) do
      post api_green_lanes_faq_feedback_index_path, params: params, headers: headers, as: :json
    end

    let(:params) do
      {
        data: {
          type: :green_lanes_faq_feedback,
          attributes: attributes,
        },
      }
    end

    let(:headers) do
      {
        'HTTP_AUTHORIZATION' => authorization,
        'Accept' => 'application/vnd.hmrc.2.0+json',
        'Content-Type' => 'application/json',
      }
    end

    context 'with valid params' do
      let(:attributes) { attributes_for(:green_lanes_faq_feedback) }

      it { is_expected.to have_http_status :created }
    end

    context 'with invalid params' do
      let(:attributes) { attributes_for(:green_lanes_faq_feedback, session_id: nil) }

      it { is_expected.to have_http_status :unprocessable_content }

      it 'returns errors for faq_feedback' do
        expect(json_response).to include('errors')
      end
    end
  end
end
