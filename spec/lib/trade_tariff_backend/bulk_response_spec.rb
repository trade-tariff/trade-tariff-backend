RSpec.describe TradeTariffBackend::BulkResponse do
  describe '.check!' do
    let(:context) { 'Search::CommodityIndex page 1' }

    def rejection_item(id)
      {
        'index' => {
          '_index' => 'tariff-uk-commodities',
          '_id' => id,
          'status' => 429,
          'error' => {
            'type' => 'es_rejected_execution_exception',
            'reason' => 'rejected execution of coordinating operation',
          },
        },
      }
    end

    def mapping_item(id)
      {
        'index' => {
          '_index' => 'tariff-uk-commodities',
          '_id' => id,
          'status' => 400,
          'error' => {
            'type' => 'mapper_parsing_exception',
            'reason' => "failed to parse field [validity_start_date] of type [date] in document with id '#{id}'",
          },
        },
      }
    end

    it 'returns the response when there are no errors' do
      response = { 'errors' => false, 'items' => [{ 'index' => { '_id' => '1', 'status' => 201 } }] }

      expect(described_class.check!(response, context)).to eq(response)
    end

    it 'returns the response when the payload is not a hash' do
      expect(described_class.check!(true, context)).to be(true)
    end

    it 'raises a mapping error when an item failed with a permanent error' do
      response = { 'errors' => true, 'items' => [mapping_item('101'), { 'index' => { '_id' => '102', 'status' => 201 } }] }

      expect { described_class.check!(response, context) }
        .to raise_error(TradeTariffBackend::BulkResponse::BulkIndexingError, /mapper_parsing_exception/)
    end

    it 'raises a rejected error when every failure is a queue rejection' do
      response = { 'errors' => true, 'items' => [rejection_item('101'), rejection_item('102')] }

      expect { described_class.check!(response, context) }
        .to raise_error(TradeTariffBackend::BulkResponse::BulkRejectedError, /es_rejected_execution_exception/)
    end

    it 'raises the permanent error class when rejections are mixed with mapping failures' do
      response = { 'errors' => true, 'items' => [rejection_item('101'), mapping_item('102')] }

      expect { described_class.check!(response, context) }
        .to raise_error(TradeTariffBackend::BulkResponse::BulkIndexingError)
    end

    it 'includes the context, the failure count and the failed document ids' do
      response = { 'errors' => true, 'items' => [mapping_item('101')] }

      expect { described_class.check!(response, context) }
        .to raise_error(/Search::CommodityIndex page 1: 1 of 1 bulk items failed.*101/m)
    end

    it 'bounds the message to the first few failures plus a total count' do
      items = (1..200).map { |id| rejection_item(id.to_s) }
      response = { 'errors' => true, 'items' => items }

      expect { described_class.check!(response, context) }
        .to raise_error(TradeTariffBackend::BulkResponse::BulkRejectedError) { |error|
          expect(error.message).to include('200 of 200 bulk items failed')
          expect(error.message).to include('and 195 more')
          expect(error.message.length).to be < 2_000
          expect(error.message).not_to include('"_id" => "6"')
        }
    end

    it 'truncates a very long failure reason' do
      item = mapping_item('101')
      item['index']['error']['reason'] = 'x' * 5_000
      response = { 'errors' => true, 'items' => [item] }

      expect { described_class.check!(response, context) }
        .to raise_error(TradeTariffBackend::BulkResponse::BulkIndexingError) { |error|
          expect(error.message.length).to be < 1_000
          expect(error.message).to include('...')
        }
    end

    it 'summarises the failure counts by error type' do
      response = { 'errors' => true, 'items' => [mapping_item('101'), rejection_item('102'), rejection_item('103')] }

      expect { described_class.check!(response, context) }
        .to raise_error(/es_rejected_execution_exception: 2/)
    end

    it 'raises when the flag is set but no item carries an error object' do
      response = { 'errors' => true, 'items' => [{ 'index' => { '_id' => '1', 'status' => 201 } }] }

      expect { described_class.check!(response, context) }
        .to raise_error(TradeTariffBackend::BulkResponse::BulkIndexingError, /unknown/)
    end
  end
end
