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
      post api_green_lanes_faq_feedback_index_path(format: :json), params: faq_feedback_data, headers: {
        'HTTP_AUTHORIZATION' => authorization,
      }
    end

    let :faq_feedback_data do
      { data: { type: :green_lanes_faq_feedback, attributes: ex_attrs } }
    end

    context 'with valid params' do
      let(:ex_attrs) { build(:green_lanes_faq_feedback).to_hash }

      it { is_expected.to have_http_status :created }
      it { is_expected.to have_attributes location: api_green_lanes_faq_feedback_url(GreenLanes::FaqFeedback.last.id) }
    end

    context 'with invalid params' do
      let(:ex_attrs) { build(:green_lanes_faq_feedback, session_id: nil).to_hash }

      it { is_expected.to have_http_status :unprocessable_entity }

      it 'returns errors for faq_feedback' do
        expect(json_response).to include('errors')
      end
    end
  end
end
