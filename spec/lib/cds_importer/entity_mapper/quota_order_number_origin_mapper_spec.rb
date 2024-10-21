RSpec.describe CdsImporter::EntityMapper::QuotaOrderNumberOriginMapper do
  let(:xml_node) do
    {
      'hjid' => '11914339',
      'metainfo' => {
        'opType' => operation,
        'origin' => 'T',
        'status' => 'L',
        'transactionDate' => '2022-09-16T10:49:00',
      },
      'sid' => '21006',
      'quotaOrderNumberId' => '058027',
      'validityStartDate' => '2022-07-01T00:00:00',
      'quotaOrderNumberOrigin' => [
        {
          'hjid' => '11914340',
          'metainfo' => {
            'opType' => operation,
            'origin' => 'T',
            'status' => 'L',
            'transactionDate' => '2022-09-16T10:49:00',
          },
          'sid' => '21120',
          'validityStartDate' => '2022-07-01T00:00:00',
          'geographicalArea' => {
            'hjid' => '10643021',
            'sid' => '496',
            'geographicalAreaId' => '5050',
            'validityStartDate' => '2021-01-01T00:00:00',
          },
          'quotaOrderNumberOriginExclusions' => [
            {
              'hjid' => '11914399',
              'metainfo' => {
                'opType' => operation,
                'origin' => 'T',
                'status' => 'L',
                'transactionDate' => '2022-06-30T19:20:14',
              },
              'geographicalArea' => {
                'hjid' => '23522',
                'sid' => '92',
                'geographicalAreaId' => 'SI',
                'validityStartDate' => '1991-11-15T00:00:00',
              },
            },
          ],
        },
      ],
      'filename' => 'foo.zip',
    }
  end

  it_behaves_like 'an entity mapper', 'QuotaOrderNumberOrigin', 'QuotaOrderNumber' do
    let(:operation) { 'U' }

    let(:expected_values) do
      {
        validity_start_date: '2022-07-01T00:00:00.000Z',
        validity_end_date: nil,
        operation: 'U',
        operation_date: Date.parse('2022-09-16'),
        quota_order_number_origin_sid: 21_120,
        quota_order_number_sid: 21_006,
        geographical_area_id: '5050',
        geographical_area_sid: 496,
      }
    end
  end
end
