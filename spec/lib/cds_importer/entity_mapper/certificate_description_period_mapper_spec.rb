RSpec.describe CdsImporter::EntityMapper::CertificateDescriptionPeriodMapper do
  let(:xml_node) do
    {
      'hjid' => '11317072',
      'metainfo' => { 'opType' => 'C', 'origin' => 'T', 'status' => 'L', 'transactionDate' => '2021-08-09T12:01:01' },
      'certificateCode' => '071',
      'validityStartDate' => '2021-08-09T00:00:00',
      'certificateDescriptionPeriod' => {
        'hjid' => '11317073',
        'metainfo' => {
          'opType' => 'C',
          'origin' => 'T',
          'status' => 'L',
          'transactionDate' => '2021-08-09T12:01:01',
        },
        'sid' => '5033',
        'validityStartDate' => '2021-08-09T00:00:00',
      },
      'certificateType' => { 'hjid' => '318', 'certificateTypeCode' => 'Y' },
    }
  end

  it_behaves_like 'an entity mapper', 'CertificateDescriptionPeriod', 'Certificate' do
    let(:expected_values) do
      {
        validity_start_date: Time.zone.parse('2021-08-09T00:00:00.000Z'),
        validity_end_date: nil,
        national: false,
        operation: 'C',
        operation_date: Date.parse('2021-08-09'),
        certificate_description_period_sid: 5033,
        certificate_type_code: 'Y',
        certificate_code: '071',
      }
    end
  end
end
