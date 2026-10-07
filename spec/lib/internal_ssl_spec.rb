require 'rails_helper'

RSpec.describe InternalSsl do
  describe '.options' do
    subject(:options) { described_class.options }

    context 'when no internal CA is configured' do
      before { allow(TradeTariffBackend).to receive(:internal_ca_pem).and_return(nil) }

      it { is_expected.to eq({}) }
    end

    context 'when an internal CA is configured' do
      let(:certificate) do
        key = OpenSSL::PKey::RSA.new(2048)
        name = OpenSSL::X509::Name.parse('/CN=*.tariff.internal')

        OpenSSL::X509::Certificate.new.tap do |cert|
          cert.version = 2
          cert.serial = 1
          cert.subject = name
          cert.issuer = name
          cert.public_key = key.public_key
          cert.not_before = Time.zone.now
          cert.not_after = 1.hour.from_now
          cert.sign(key, OpenSSL::Digest.new('SHA256'))
        end
      end

      before { allow(TradeTariffBackend).to receive(:internal_ca_pem).and_return(certificate.to_pem) }

      it { is_expected.to include(cert_store: an_instance_of(OpenSSL::X509::Store)) }

      it 'trusts the internal certificate' do
        expect(options[:cert_store].verify(certificate)).to be true
      end

      it 'still trusts the system CA bundle' do
        bundle = OpenSSL::X509::DEFAULT_CERT_FILE
        skip "no system CA bundle at #{bundle}" unless File.exist?(bundle)

        pem = File.read(bundle)[/-----BEGIN CERTIFICATE-----.*?-----END CERTIFICATE-----/m]
        skip "no certificates in #{bundle}" if pem.nil?

        expect(options[:cert_store].verify(OpenSSL::X509::Certificate.new(pem))).to be true
      end
    end
  end
end
