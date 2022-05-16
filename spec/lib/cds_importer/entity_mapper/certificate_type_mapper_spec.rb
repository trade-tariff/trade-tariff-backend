RSpec.describe CdsImporter::EntityMapper::CertificateTypeMapper do
  it_behaves_like 'an entity mapper', 'CertificateType', 'CertificateType' do
    let(:xml_node) do
      {
        'certificateTypeCode' => 'A',
        'validityStartDate' => '2017-06-29',
        'certificateTypeDescription' => {
          'description' => 'foo',
          'language' => { 'languageId' => 'EN' },
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
        validity_start_date: Date.parse('2017-06-29'),
        validity_end_date: nil,
        national: true,
        operation: 'U',
        operation_date: Date.parse('2017-06-29'),
        certificate_type_code: 'A',
      }
    end
  end
end
