RSpec.describe Api::V2::CertificatesController, type: :controller do
  routes { V2Api.routes }

  describe 'GET #index' do
    subject(:do_response) do
      get :index, format: :json
      response.body
    end

    let(:certificate) do
      create(
        :certificate,
        :with_description,
        :with_certificate_type,
        :with_guidance,
      )
    end

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
              guidance_cds: String,
              # guidance_chief: String,
            },
          },
        ],
      }
    end

    before do
      certificate
    end

    it { is_expected.to match_json_expression(pattern) }

    context 'when the validity_end_date is set to a past date' do
      let(:certificate) { create(:certificate, validity_end_date: 1.day.ago) }

      it { is_expected.to match_json_expression({ data: [] }) }
    end
  end
end
