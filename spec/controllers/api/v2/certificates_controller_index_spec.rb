RSpec.describe Api::V2::CertificatesController, type: :controller do
  describe 'GET #index' do
    let(:certificate) { create :certificate }

    let(:certificate_type) do
      create :certificate_type, :with_description,
             certificate_type_code: certificate.certificate_type_code
    end

    let(:certificate_description) do
      create :certificate_description,
             :with_period,
             certificate_type_code: certificate.certificate_type_code,
             certificate_code: certificate.certificate_code
    end

    let(:expected_response) do
      {
        data: [{
          id: String,
          type: 'certificate_type',
          attributes: {
            certificate_type_code: String,
            certificate_code: String,
            description: String,
            formatted_description: String,
            certificate_type_description: String,
            validity_start_date: String,
          },
        }],
      }
    end

    before do
      certificate
      certificate_description
      certificate_type

      allow(TimeMachine).to receive(:at).and_call_original
    end

    it 'returns a list of certificates' do
      get :index, format: :json

      response_data_type = JSON.parse(response.body)['data'].first['type']

      expect(response_data_type).to eq('certificate_type')
    end

    it 'the TimeMachine receives the correct Date' do
      get :index, format: :json

      expect(TimeMachine).to have_received(:at).with(Time.zone.today)
    end
  end
end
