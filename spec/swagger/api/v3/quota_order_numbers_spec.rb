require 'swagger_helper'

RSpec.describe 'Quota Order Numbers V3', swagger_doc: 'v3/swagger.json', type: :request do
  let(:Accept) { 'application/vnd.hmrc.3.0+json' }

  path '/api/v3/quota_order_numbers' do
    get 'List all quota order numbers' do
      tags 'Quotas'
      operationId 'listQuotaOrderNumbersV3'
      description 'Returns quota order numbers. Useful for looking up quota identifiers before fetching quota details.'

      response '200', 'quota order numbers listed' do
        schema type: :object

        run_test!
      end
    end
  end
end
