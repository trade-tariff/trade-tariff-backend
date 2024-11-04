RSpec.describe Api::V2::GreenLanes::CertificatePresenter do
  subject(:presented) { described_class.new(certificate, measure_id, group_ids) }

  let(:certificate) { create :certificate }

  let(:group_ids) { { certificate.id => '1' } }

  let(:measure_id) { 'measure_id' }

  it { is_expected.to have_attributes id: /^[0-9a-f]{32}$/ }
  it { is_expected.to have_attributes group_ids: '1' }
  it { is_expected.to have_attributes(measure_id:) }
  it { is_expected.to have_attributes certificate_id: certificate.certificate_type_code + certificate.certificate_code }
end
