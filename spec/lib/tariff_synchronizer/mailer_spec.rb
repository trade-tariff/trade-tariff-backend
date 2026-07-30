RSpec.describe TariffSynchronizer::Mailer do
  describe '#applied' do
    subject(:mail) { described_class.applied(update_names, import_warnings) }

    let(:update_names) { %w[2024-01-01_xi_taric_update.xml] }

    before do
      allow(TaricSynchronizer).to receive(:ignore_presence_errors).and_return(false)
      allow(TariffSynchronizer::TariffUpdatePresenceError).to receive(:where).and_return([])
    end

    context 'when there are no import warnings and no presence errors' do
      let(:import_warnings) { [] }

      it 'returns a null mail with no subject' do
        expect(mail.subject).to be_nil
      end
    end

    context 'when there are import warnings' do
      let(:import_warnings) { [{ message: 'Unexpected element', xml_node: '<foo/>' }] }

      it 'delivers the mail' do
        expect(mail.subject).to be_present
      end

      it 'uses a warn subject prefix' do
        expect(mail.subject).to include('[warn]')
      end

      it 'describes the situation in the subject' do
        expect(mail.subject).to include('Tariff updates applied with warnings')
      end
    end

    context 'when presence errors exist and ignore_presence_errors is enabled' do
      let(:import_warnings) { [] }
      let(:presence_error) { instance_double(TariffSynchronizer::TariffUpdatePresenceError, details: {}) }

      before do
        allow(TaricSynchronizer).to receive(:ignore_presence_errors).and_return(true)
        allow(TariffSynchronizer::TariffUpdatePresenceError).to receive(:where)
          .with(tariff_update_filename: update_names)
          .and_return([presence_error])
      end

      it 'delivers the mail' do
        expect(mail.subject).to be_present
      end

      it 'uses a warn subject prefix' do
        expect(mail.subject).to include('[warn]')
      end
    end
  end
end
