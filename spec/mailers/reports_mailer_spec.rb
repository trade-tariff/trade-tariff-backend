RSpec.describe ReportsMailer, type: :mailer do
  describe '#differences' do
    subject(:mail) { described_class.differences(report).tap(&:deliver_now) }

    let(:report) { Reporting::Differences.new }
    let(:attachment) { mail.attachments["differences_#{report.as_of}.xlsx"] }
    let(:xlsx_content) { "PK\x03\x04\x9D".b }

    before do
      allow(report).to receive(:workbook_data).and_return(xlsx_content)
    end

    it { expect(mail.subject).to eq("[HMRC Online Trade Tariff Support] UK tariff - potential issues report #{Time.zone.today.iso8601}") }
    it { expect(mail.from).to eq(['no-reply@example.com']) }
    it { expect(mail.to).to eq(['differences@example.com']) }
    it { expect(mail.bcc).to eq(['user@example.com']) }

    it 'encodes the xlsx attachment as base64' do
      expect(attachment.body.raw_source).to be_ascii_only
      expect(Base64.strict_decode64(attachment.body.raw_source)).to eq(xlsx_content)
    end
  end

  describe '#search_reference_changes' do
    subject(:mail) { described_class.search_reference_changes(result).tap(&:deliver_now) }

    let(:result) do
      Reporting::SearchReferenceChanges::Result.new(
        period: Date.new(2026, 10, 1)..Date.new(2026, 10, 31),
        entries:,
        csv_data: "Section,Title\r\nAdded,live horses\r\n",
        filename: 'search_reference_changes_uk_2026_10.csv',
      )
    end

    let(:entries) do
      [
        build_entry(section: :expired, title: 'old horses', changed_by: 'ClearInvalidSearchReferences'),
        build_entry(section: :added, title: 'live horses', changed_by: '11111111-1111-4111-8111-111111111111'),
        build_entry(section: :added, title: 'ponies', changed_by: '11111111-1111-4111-8111-111111111111'),
      ]
    end

    let(:body) { mail.html_part&.body&.decoded || mail.body.decoded }

    def build_entry(section:, title:, changed_by:, changed_by_name: nil)
      SearchReferences::ChangeEntry.new(
        version_id: 1,
        search_reference_id: '1',
        section:,
        changed_at: Time.utc(2026, 10, 3),
        changed_by:,
        changed_by_name:,
        goods_nomenclature_item_id: '0101210000',
        productline_suffix: '80',
        title:,
        usage: SearchReference::SEARCH_USAGE,
        goods_nomenclature_url: nil,
        successor_ids: [],
        previous_goods_nomenclature_item_id: nil,
        previous_title: nil,
        previous_usage: nil,
      )
    end

    before { allow(TradeTariffBackend).to receive(:service).and_return('uk') }

    it { expect(mail.subject).to eq('[HMRC Online Trade Tariff Support] UK tariff - search reference changes October 2026') }
    it { expect(mail.to).to eq(['search-references@example.com']) }
    it { expect(mail.bcc).to eq(['user@example.com']) }

    it 'attaches the report CSV' do
      attachment = mail.attachments['search_reference_changes_uk_2026_10.csv']

      expect(attachment.content_type).to start_with('text/csv')
      expect(attachment.body.decoded).to eq(result.csv_data)
    end

    it 'lists the number of changes for each operation' do
      expect(body).to include('Changes by operation', 'Expired: 1', 'Added: 2')
    end

    it 'does not list the individual changes', :aggregate_failures do
      expect(body).not_to include('old horses', 'live horses', 'ponies')
      expect(body).to include('The full list of changes is in the attached CSV file.')
    end

    it 'lists the number of changes by readable source, with a breakdown per admin user', :aggregate_failures do
      expect(body).to include('Admin users: 2', 'Admin user: 2', 'Automatic clean-up: 1')
      expect(body).not_to include('11111111-1111-4111-8111-111111111111')
    end

    context 'when the admin user has a stored name' do
      let(:entries) do
        [
          build_entry(section: :added, title: 'live horses', changed_by: '11111111-1111-4111-8111-111111111111', changed_by_name: 'Zoë <Smith>'),
          build_entry(section: :added, title: 'ponies', changed_by: '11111111-1111-4111-8111-111111111111'),
        ]
      end

      it 'shows the escaped name instead of the user ID' do
        expect(body).to include('Zoë &lt;Smith&gt;: 2')
        expect(body).not_to include('11111111-1111-4111-8111-111111111111')
      end
    end

    context 'when on the XI service' do
      before { allow(TradeTariffBackend).to receive(:service).and_return('xi') }

      it { expect(mail.subject).to eq('[HMRC Online Trade Tariff Support] Northern Ireland tariff - search reference changes October 2026') }
    end

    context 'when there are no changes' do
      let(:entries) { [] }

      it { expect(body).to include('There were no search reference changes in this period.') }
      it { expect(mail.attachments.size).to eq(1) }
    end

    context 'when no recipients are configured' do
      before { allow(TradeTariffBackend).to receive(:search_references_report_to_emails).and_return([]) }

      it 'does not send an email' do
        expect { mail }.not_to change(ActionMailer::Base.deliveries, :count)
      end
    end
  end
end
