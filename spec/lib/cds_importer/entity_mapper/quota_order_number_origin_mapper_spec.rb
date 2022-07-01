RSpec.describe CdsImporter::EntityMapper::QuotaOrderNumberOriginMapper do
  let(:xml_node) do
    {
      'sid' => '12113',
      'quotaOrderNumberOrigin' => {
        'sid' => '1485',
        'geographicalArea' => {
          'sid' => '11993',
          'geographicalAreaId' => '1101',
        },
        'quotaOrderNumberOriginExclusion' => {
          'geographicalArea' => {
            'sid' => '11993',
            'geographicalAreaId' => '1101',
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

  it_behaves_like 'an entity mapper', 'QuotaOrderNumberOrigin', 'QuotaOrderNumber' do
    let(:expected_values) do
      {
        validity_start_date: Time.zone.parse('1970-01-01T00:00:00.000Z'),
        validity_end_date: Time.zone.parse('1971-01-01T00:00:00.000Z'),
        operation: 'C',
        operation_date: Date.parse('2017-04-11'),
        quota_order_number_origin_sid: 1485,
        quota_order_number_sid: 12_113,
        geographical_area_id: '1101',
        geographical_area_sid: 11_993,
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
          :quota_order_number_origin,
          :with_quota_order_number_origin_exclusion,
          quota_order_number_origin_sid: 1485,
        )

        # Control for non-deleted secondary entities
        create(
          :quota_order_number_origin_exclusion,
          quota_order_number_origin_sid: 1485,
          excluded_geographical_area_sid: 11_993,
        )
      end

      it_behaves_like 'an entity mapper missing destroy operation', QuotaOrderNumberOriginExclusion, quota_order_number_origin_sid: '1485'
    end
  end
end
