RSpec.describe TariffSynchronizer::Mailer do
  describe '#applied' do
    subject(:mail) { described_class.applied(update_names, import_warnings) }

    let(:update_names) { %w[2024-01-01_xi_taric_update.xml] }

    context 'when there are import warnings' do
      let(:import_warnings) { [{ message: 'Unexpected element', xml_node: '<foo/>' }] }

      it 'delivers the mail' do
        expect(mail.subject).to be_present
      end

      it 'uses a warn subject prefix' do
        expect(mail.subject).to include('[warn]')
      end

      it 'describes the situation in the subject' do
        expect(mail.subject).to include('Tariff updates applied')
      end
    end

    it 'does not mention presence errors' do
      mail = described_class.applied(update_names, [{ message: 'Unexpected element', xml_node: '<foo/>' }])
      expect(mail.body.encoded).not_to include('presence errors')
    end
  end
end
