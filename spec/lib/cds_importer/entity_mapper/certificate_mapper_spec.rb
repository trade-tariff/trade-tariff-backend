RSpec.describe CdsImporter::EntityMapper::CertificateMapper do
  it_behaves_like 'an entity mapper' do
    let(:xml_node) do
      {
        'hjid' => '11317072',
        'metainfo' => { 'opType' => 'C', 'origin' => 'T', 'status' => 'L', 'transactionDate' => '2021-08-09T12:01:01' },
        'certificateCode' => '071',
        'validityStartDate' => '2021-08-09T00:00:00',
        'certificateDescriptionPeriod' => {
          'hjid' => '11317073',
          'metainfo' => { 'opType' => 'C', 'origin' => 'T', 'status' => 'L', 'transactionDate' => '2021-08-09T12:01:01' },
          'sid' => '5033',
          'validityStartDate' => '2021-08-09T00:00:00',
          'certificateDescription' => {
            'hjid' => '11317074',
            'metainfo' => { 'opType' => 'C', 'origin' => 'T', 'status' => 'L', 'transactionDate' => '2021-08-09T12:01:01' },
            'description' => 'Goods that have originated from or shipped from Belarus, subject to a contract signed before 9 August 2021',
            'language' => { 'hjid' => '9', 'languageId' => 'EN' },
          },
        },
        'certificateType' => { 'hjid' => '318', 'certificateTypeCode' => 'Y' },
      }
    end

    let(:expected_values) do
      {
        validity_start_date: Time.parse('2021-08-09T00:00:00.000Z'),
        validity_end_date: nil,
        national: false,
        operation: 'C',
        operation_date: Date.parse('2021-08-09'),
        certificate_type_code: 'Y',
        certificate_code: '071',
      }
    end

    let(:expected_entity_class) { 'Certificate' }
    let(:expected_mapping_root) { 'Certificate' }
  end
end
