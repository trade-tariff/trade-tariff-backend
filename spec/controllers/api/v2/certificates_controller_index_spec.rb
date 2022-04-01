RSpec.describe Api::V2::CertificatesController, type: :controller do
  describe 'GET #index' do
    subject(:do_response) do
      get :index, format: :json
      response.body
    end

    let(:certificate) { create(:certificate, :with_description, :with_certificate_type) }

    let(:pattern) do
      {
        data: [
          {
            id: String,
            type: 'certificate',
            attributes: {
              certificate_type_code: String,
              certificate_code: String,
              description: String,
              formatted_description: String,
              certificate_type_description: String,
              validity_start_date: String,
            },
          },
        ],
      }
    end

    before do
      certificate
    end

    it { is_expected.to match_json_expression(pattern) }

    it 'the TimeMachine receives the correct Date' do
      allow(TimeMachine).to receive(:at).and_call_original

      do_response

      expect(TimeMachine).to have_received(:at).with(Time.zone.today)
    end
  end
end
