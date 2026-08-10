RSpec.describe Api::V2::Categorisation::FaqFeedbackController, :v2 do
  subject(:api_response) do
    make_request
    response
  end

  before do
    allow(TradeTariffBackend).to receive(:uk?).and_return(false)
  end

  describe 'POST to #create' do
    let(:make_request) do
      post api_categorisation_faq_feedback_index_path, params: params, headers: headers, as: :json
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
        'Accept' => 'application/vnd.hmrc.2.0+json',
        'Content-Type' => 'application/json',
      }
    end

    context 'with valid params and no legacy API key/token' do
      let(:attributes) { attributes_for(:green_lanes_faq_feedback) }

      it { is_expected.to have_http_status :created }
    end

    context 'with invalid params' do
      let(:attributes) { attributes_for(:green_lanes_faq_feedback, session_id: nil) }

      it { is_expected.to have_http_status :unprocessable_content }
    end
  end
end
