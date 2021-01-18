require 'rails_helper'

describe CertificateType do
  describe 'validations' do
    # CET1: certificate_type_id
    it { is_expected.to validate_uniqueness.of :certificate_type_code }
    # CET3: validity_dates
    it { is_expected.to validate_validity_dates }

    describe 'CET2' do
      let!(:certificate_type) { create :certificate_type }
      let!(:certificate)      { create :certificate, certificate_type_code: certificate_type.certificate_type_code }

      before do
        certificate_type.destroy
        certificate_type.conformant?
      end

      specify 'The certificate type cannot be deleted if it is used in a certificate.' do
        expect(certificate_type.conformance_errors.keys).to include :CET2
      end
    end
  end
end
