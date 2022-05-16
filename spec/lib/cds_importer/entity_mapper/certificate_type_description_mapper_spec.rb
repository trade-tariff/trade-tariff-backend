RSpec.describe CdsImporter::EntityMapper::CertificateTypeDescriptionMapper do
  it_behaves_like 'an entity mapper', 'CertificateTypeDescription', 'CertificateType' do
    let(:xml_node) do
      {
        'certificateTypeCode' => 'A',
        'validityStartDate' => '2017-06-29',
        'certificateTypeDescription' => {
          'description' => 'foo',
          'language' => { 'languageId' => 'EN' },
          'metainfo' => {
            'opType' => 'U',
            'origin' => 'N',
            'transactionDate' => '2017-06-30T20:04:37',
          },
        },
        'metainfo' => {
          'opType' => 'U',
          'origin' => 'N',
          'transactionDate' => '2017-06-29T20:04:37',
        },
      }
    end

    let(:expected_values) do
      {
        national: true,
        operation: 'U',
        operation_date: Date.parse('2017-06-30'),
        certificate_type_code: 'A',
        language_id: 'EN',
        description: 'foo',
      }
    end
  end
end
