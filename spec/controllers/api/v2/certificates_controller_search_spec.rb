RSpec.describe Api::V2::CertificatesController, type: :controller do
  describe 'GET #search' do
    subject(:do_response) { get :search, params: { code: certificate.certificate_code }, format: :json && response }

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
              measures: {
                data: [
                  {
                    id: String,
                    type: 'measure',
                  },
                ],
              },
            },
          },
        ],
        included: [
          {
            id: String,
            type: 'measure',
            attributes: {
              goods_nomenclature_item_id: String,
              validity_start_date: String,
              validity_end_date: nil,
            },
            relationships: {
              goods_nomenclature: {
                data: {
                  id: String,
                  type: 'heading',
                },
              },
              geographical_area: {
                data: {
                  id: String,
                  type: 'geographical_area',
                },
              },
            },
          },
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
        meta: {
          pagination: {
            page: Integer,
            per_page: Integer,
            total_count: Integer,
          },
        },
      }
    end

    before do
      create(
        :measure,
        :with_measure_conditions,
        goods_nomenclature: create(:heading, :with_description),
        certificate_type_code: certificate.certificate_type_code,
        certificate_code: certificate.certificate_code,
      )

      Sidekiq::Testing.inline! do
        TradeTariffBackend.cache_client.reindex(Cache::CertificateIndex.new)
        sleep(1)
      end
    end

    it { expect(do_response.body).to match_json_expression pattern }
  end
end
