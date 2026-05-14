RSpec.describe Api::V2::MeasureConditionCodesController, type: :request do
  describe '#index' do
    subject(:api_response) do
      make_request
      response
    end

    let(:make_request) do
      get '/uk/api/measure_condition_codes', headers: request_headers
    end

    let(:json_body) { JSON.parse(api_response.body)['data'] }
    let(:validity_end_date) { nil }

    before do
      create(:measure_condition_code, :with_description, condition_code: 'C', validity_end_date:)

      allow(TimeMachine).to receive(:at).and_call_original
    end

    it { is_expected.to have_http_status(:success) }

    it 'returns all measure actions' do
      expect(json_body).to eq(
        [
          {
            'id' => 'C',
            'type' => 'measure_condition_code',
            'attributes' => {
              'description' => 'Presentation of a certificate/licence/document',
              'validity_start_date' => 3.years.ago.beginning_of_day.as_json,
              'validity_end_date' => nil,
            },
          },
        ],
      )
    end

    context 'when the validity_end_date is set to a past date' do
      let(:validity_end_date) { 1.day.ago }

      it { expect(json_body).to eq [] }
    end
  end
end
