RSpec.describe CdsImporter::EntityMapper::QuotaOrderNumberMapper do
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

  it_behaves_like 'an entity mapper', 'QuotaOrderNumber', 'QuotaOrderNumber' do
    let(:operation) { 'U' }

    let(:expected_values) do
      {
        validity_start_date: '2022-07-01T00:00:00.000Z',
        validity_end_date: nil,
        operation: 'U',
        operation_date: Date.parse('2022-09-16 2022'),
        quota_order_number_sid: 21_006,
        quota_order_number_id: '058027',
      }
    end
  end

  describe '#import' do
    subject(:entity_mapper) { CdsImporter::EntityMapper.new('QuotaOrderNumber', xml_node) }

    context 'when the quota_order_number is being updated' do
      let(:operation) { 'U' }

      it_behaves_like 'an entity mapper update operation', QuotaOrderNumber
      it_behaves_like 'an entity mapper update operation', QuotaOrderNumberOrigin
      it_behaves_like 'an entity mapper update operation', QuotaOrderNumberOriginExclusion
    end

    context 'when the quota_order_number is being created' do
      let(:operation) { 'C' }

      it_behaves_like 'an entity mapper create operation', QuotaOrderNumber
      it_behaves_like 'an entity mapper create operation', QuotaOrderNumberOrigin
      it_behaves_like 'an entity mapper create operation', QuotaOrderNumberOriginExclusion
    end

    context 'when the quota_order_number is being deleted' do
      before do
        create(:quota_order_number, quota_order_number_sid: '21006')
        create(:quota_order_number_origin, quota_order_number_origin_sid: '21120')
        create(:quota_order_number_origin_exclusion, quota_order_number_origin_sid: '21120', excluded_geographical_area_sid: '92')
      end

      let(:operation) { 'D' }

      it_behaves_like 'an entity mapper destroy operation', QuotaOrderNumber
      it_behaves_like 'an entity mapper destroy operation', QuotaOrderNumberOrigin
      it_behaves_like 'an entity mapper destroy operation', QuotaOrderNumberOriginExclusion
    end
  end
end
