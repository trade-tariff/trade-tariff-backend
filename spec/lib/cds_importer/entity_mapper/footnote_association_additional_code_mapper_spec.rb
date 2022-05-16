RSpec.describe CdsImporter::EntityMapper::FootnoteAssociationAdditionalCodeMapper do
  it_behaves_like 'an entity mapper', 'FootnoteAssociationAdditionalCode', 'AdditionalCode' do
    let(:xml_node) do
      {
        'sid' => '3084',
        'additionalCodeCode' => '169',
        'validityEndDate' => '1996-06-14T23:59:59',
        'validityStartDate' => '1991-06-01T00:00:00',
        'additionalCodeType' => {
          'additionalCodeTypeId' => '8',
        },
        'footnoteAssociationAdditionalCode' => {
          'footnote' => {
            'footnoteId' => '08',
            'footnoteType' => {
              'footnoteTypeId' => '06',
            },
          },
          'metainfo' => {
            'opType' => 'C',
            'transactionDate' => '2017-08-27T19:23:57',
          },
        },
        'metainfo' => {
          'origin' => 'T',
          'opType' => 'U',
          'transactionDate' => '2016-07-27T09:20:15',
        },
      }
    end

    let(:expected_values) do
      {
        validity_start_date: nil,
        validity_end_date: nil,
        operation: 'C',
        operation_date: Date.parse('2017-08-27'),
        additional_code_sid: 3084,
        additional_code_type_id: '8',
        additional_code: '169',
        footnote_type_id: '06',
        footnote_id: '08',
      }
    end
  end
end
