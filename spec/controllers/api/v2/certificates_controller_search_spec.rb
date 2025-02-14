RSpec.describe Api::V2::CertificatesController, type: :controller do
  routes { V2Api.routes }

  describe 'GET #search' do
    subject(:do_response) { get :search, params:, format: :json && response }

    let(:certificate) { create(:certificate, :with_description) }

    let(:pattern) do
      {
        data: [
          {
            id: String,
            type: 'certificates',
            attributes: {
              certificate_type_code: String,
              certificate_code: String,
              description: String,
              formatted_description: String,
              guidance_chief: String,
              guidance_cds: String,
            },
            relationships: {
              goods_nomenclatures: {
                data: [
                  {
                    id: String,
                    type: 'heading',
                  },
                ],
              },
            },
          },
        ],
        included: [
          {
            id: String,
            type: 'heading',
            attributes: {
              goods_nomenclature_item_id: String,
              description: String,
              formatted_description: String,
              producline_suffix: String,
              validity_start_date: String,
              validity_end_date: nil,
            },
          },
        ],
      }
    end

    before do
      create(
        :measure,
        :with_base_regulation,
        :with_measure_conditions,
        goods_nomenclature: create(:heading, :with_description),
        certificate_type_code: certificate.certificate_type_code,
        certificate_code: certificate.certificate_code,
      )
    end

    context 'when searching by code and type' do
      let(:params) { { code: certificate.certificate_code, type: certificate.certificate_type_code } }

      it { expect(do_response.body).to match_json_expression pattern }
    end

    context 'when searching by description' do
      let(:params) { { description: certificate.description } }

      it { expect(do_response.body).to match_json_expression pattern }
    end

    context 'when searching by type' do
      let(:params) { { type: certificate.certificate_type_code } }

      let(:pattern) do
        {
          'errors' => [
            {
              'status' => 422,
              'title' => 'is required when filtering by type',
              'detail' => 'Code is required when filtering by type',
            },
          ],
        }
      end

      it { is_expected.to have_http_status :unprocessable_entity }
      it { expect(do_response.body).to match_json_expression pattern }
    end

    context 'when searching by id' do
      let(:params) { { code: certificate.certificate_code } }

      let(:pattern) do
        {
          'errors' => [
            {
              'status' => 422,
              'title' => 'is required when filtering by code',
              'detail' => 'Type is required when filtering by code',
            },
          ],
        }
      end

      it { is_expected.to have_http_status :unprocessable_entity }
      it { expect(do_response.body).to match_json_expression pattern }
    end

    context 'when searching with no params' do
      let(:params) { {} }

      let(:pattern) do
        {
          'errors' => [
            {
              'status' => 422,
              'title' => 'is required when code and type are missing',
              'detail' => 'Description is required when code and type are missing',
            },
          ],
        }
      end

      it { is_expected.to have_http_status :unprocessable_entity }
      it { expect(do_response.body).to match_json_expression pattern }
    end
  end
end
