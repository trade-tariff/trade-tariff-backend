RSpec.describe CdsImporter::EntityMapper::QuotaOrderNumberOriginExclusionMapper do
  it_behaves_like 'an entity mapper', 'QuotaOrderNumberOriginExclusion', 'QuotaOrderNumber' do
    let(:xml_node) do
      {
        'sid' => '12113',
        'quotaOrderNumberOrigin' => {
          'sid' => '1485',
          'geographicalArea' => {
            'sid' => '11993',
            'geographicalAreaId' => '1101',
            'metainfo' => {
              'opType' => 'U',
              'transactionDate' => '2017-07-15T22:27:51',
            },
          },
          'quotaOrderNumberOriginExclusion' => {
            'geographicalArea' => {
              'sid' => '11993',
              'geographicalAreaId' => '1101',
              'metainfo' => {
                'opType' => 'U',
                'transactionDate' => '2017-07-15T22:27:51',
              },
            },
            'metainfo' => {
              'opType' => 'C',
              'transactionDate' => '2017-10-14T11:55:34',
            },
          },
          'validityStartDate' => '1970-01-01T00:00:00',
          'validityEndDate' => '1971-01-01T00:00:00',
          'metainfo' => {
            'opType' => 'C',
            'transactionDate' => '2017-04-11T10:05:31',
          },
        },
        'metainfo' => {
          'opType' => 'U',
          'transactionDate' => '2017-06-29T20:04:37',
        },
      }
    end

    let(:expected_values) do
      {
        operation: 'C',
        operation_date: Date.parse('2017-10-14'),
        quota_order_number_origin_sid: 1485,
        excluded_geographical_area_sid: 11_993,
      }
    end
  end
end
