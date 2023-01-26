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

  describe '#import' do
    subject(:entity_mapper) { CdsImporter::EntityMapper.new('QuotaOrderNumber', xml_node) }

    context 'when there are missing secondary entities to be soft deleted' do
      let(:operation) { 'C' }

      before do
        # Creates entities that will be missing from the xml node
        create(
          :quota_order_number,
          :with_quota_order_number_origin,
          quota_order_number_sid: '21006',
          quota_order_number_origin_sid: '21120',
        )

        # Control for non-deleted secondary entities
        create(:quota_order_number_origin_exclusion, quota_order_number_origin_sid: '21120', excluded_geographical_area_sid: '92')
      end

      it_behaves_like 'an entity mapper missing destroy operation', QuotaOrderNumberOriginExclusion, quota_order_number_origin_sid: '21120'
    end
  end
end
