RSpec.describe CdsImporter::EntityMapper::CertificateMapper do
  let(:xml_node) do
    {
      'hjid' => '11317072',
      'metainfo' => { 'opType' => operation, 'origin' => 'T', 'status' => 'L', 'transactionDate' => '2021-08-09T12:01:01' },
      'certificateCode' => '071',
      'validityStartDate' => '2021-08-09T00:00:00',
      'certificateDescriptionPeriod' => {
        'hjid' => '11317073',
        'metainfo' => { 'opType' => operation, 'origin' => 'T', 'status' => 'L', 'transactionDate' => '2021-08-09T12:01:01' },
        'sid' => '5033',
        'validityStartDate' => '2021-08-09T00:00:00',
        'certificateDescription' => {
          'hjid' => '11317074',
          'metainfo' => { 'opType' => operation, 'origin' => 'T', 'status' => 'L', 'transactionDate' => '2021-08-09T12:01:01' },
          'description' => 'Goods that have originated from or shipped from Belarus, subject to a contract signed before 9 August 2021',
          'language' => { 'hjid' => '9', 'languageId' => 'EN' },
        },
      },
      'certificateType' => { 'hjid' => '318', 'certificateTypeCode' => 'Y' },
    }
  end

  let(:operation) { 'C' }

  it_behaves_like 'an entity mapper', 'Certificate', 'Certificate' do
    let(:expected_values) do
      {
        validity_start_date: Time.zone.parse('2021-08-09T00:00:00.000Z'),
        validity_end_date: nil,
        national: false,
        operation: 'C',
        operation_date: Date.parse('2021-08-09'),
        certificate_type_code: 'Y',
        certificate_code: '071',
      }
    end
  end

  describe '#import' do
    subject(:entity_mapper) { CdsImporter::EntityMapper.new('Certificate', xml_node) }

    context 'when the certificate is being updated' do
      let(:operation) { 'U' }

      it_behaves_like 'an entity mapper update operation', Certificate
      it_behaves_like 'an entity mapper update operation', CertificateDescription
      it_behaves_like 'an entity mapper update operation', CertificateDescriptionPeriod
    end

    context 'when the certificate is being created' do
      let(:operation) { 'C' }

      it_behaves_like 'an entity mapper create operation', Certificate
      it_behaves_like 'an entity mapper create operation', CertificateDescription
      it_behaves_like 'an entity mapper create operation', CertificateDescriptionPeriod
    end
  end
end
