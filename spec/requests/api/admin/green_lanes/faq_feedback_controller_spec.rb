RSpec.describe Api::Admin::GreenLanes::FaqFeedbackController do
  subject(:page_response) { make_request && response }

  let(:json_response) { JSON.parse(page_response.body) }
  let(:faq_feedback) { create :green_lanes_faq_feedback }

  describe 'POST to #create' do
    let(:make_request) do
      authenticated_post api_green_lanes_faq_feedback_index_path(format: :json), params: faq_feedback_data
    end
    let :faq_feedback_data do
      {
        data: {
          type: :green_lanes_faq_feedback,
          attributes: ex_attrs,
        },
      }
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
