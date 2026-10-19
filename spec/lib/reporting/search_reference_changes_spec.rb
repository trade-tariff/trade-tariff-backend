RSpec.describe Reporting::SearchReferenceChanges do
  let(:today) { Date.new(2026, 11, 2) }
  let(:commodity) { create(:commodity, goods_nomenclature_item_id: '0101210000') }
  let(:admin_uid) { '11111111-1111-4111-8111-111111111111' }
  let(:other_admin_uid) { '22222222-2222-4222-8222-222222222222' }

  before { travel_to today.beginning_of_day + 10.hours }

  def create_reference_at(time, title:, whodunnit: admin_uid, whodunnit_name: nil)
    travel_to(time) do
      TradeTariffRequest.set(whodunnit:, whodunnit_name:) { create(:search_reference, referenced: commodity, title:) }
    end
  end

  describe '.default_period' do
    it 'is the previous calendar month' do
      expect(described_class.default_period).to eq(Date.new(2026, 10, 1)..Date.new(2026, 10, 31))
    end
  end

  describe '.object_key' do
    it 'is dated today and named after the period' do
      expect(described_class.object_key).to eq(
        "#{TradeTariffBackend.service}/reporting/2026/11/02/search_reference_changes_#{TradeTariffBackend.service}_2026_10.csv",
      )
    end
  end

  describe '.bucket' do
    it 'is the private persistence bucket, not the public reporting bucket', :aggregate_failures do
      expect(described_class.bucket).to eq(Rails.application.config.persistence_bucket)
      expect(described_class.bucket).not_to eq(Rails.application.config.reporting_bucket)
    end
  end

  context 'when running in production' do
    let(:persistence_bucket) { Rails.application.config.persistence_bucket }

    before do
      allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('production'))
      persistence_bucket.client.setup_stubbing
      persistence_bucket.client.api_requests.clear
    end

    describe '.available_today?' do
      it 'is true when the object exists in the persistence bucket' do
        persistence_bucket.client.stub_responses(:head_object, {})

        expect(described_class.available_today?).to be(true)
      end

      it 'is false when the object does not exist' do
        persistence_bucket.client.stub_responses(:head_object, 'NotFound')

        expect(described_class.available_today?).to be(false)
      end

      it 'is false when S3 fails' do
        persistence_bucket.client.stub_responses(:head_object, 'ServiceUnavailable')

        expect(described_class.available_today?).to be(false)
      end
    end

    describe '.download_link_today' do
      subject(:uri) { URI.parse(described_class.download_link_today) }

      def query
        Rack::Utils.parse_query(uri.query)
      end

      it 'is a presigned URL for the object in the persistence bucket', :aggregate_failures do
        expect(uri.host).to start_with("#{persistence_bucket.name}.")
        expect(uri.path).to eq("/#{described_class.object_key}")
        expect(query).to include('X-Amz-Signature', 'X-Amz-Expires' => described_class::DOWNLOAD_URL_EXPIRES_IN.to_s)
      end

      it 'asks the browser to download the file' do
        expect(query['response-content-disposition']).to eq(%(attachment; filename="#{File.basename(described_class.object_key)}"))
      end
    end
  end

  describe '.generate' do
    subject(:result) { described_class.generate }

    context 'when there are changes in and around the period' do
      before do
        create_reference_at(Time.utc(2026, 9, 30, 23, 59), title: 'before period')
        create_reference_at(Time.utc(2026, 10, 1, 0, 0), title: 'start of period')
        updated = create_reference_at(Time.utc(2026, 10, 15), title: 'to update')
        travel_to(Time.utc(2026, 10, 16)) do
          TradeTariffRequest.set(whodunnit: other_admin_uid) { updated.update(title: 'updated') }
        end
        create_reference_at(Time.utc(2026, 10, 31, 23, 59), title: 'end of period', whodunnit: SearchReferences::FpoCsvImporter::DEFAULT_WHODUNNIT)
        create_reference_at(Time.utc(2026, 11, 1, 0, 0), title: 'after period')
      end

      it 'includes only changes in the period' do
        expect(result.entries.map(&:title)).to contain_exactly('start of period', 'to update', 'end of period', 'updated')
      end

      it 'orders entries by section, then by time' do
        expect(result.entries.map { |entry| [entry.section, entry.title] }).to eq(
          [
            [:added, 'start of period'],
            [:added, 'to update'],
            [:added, 'end of period'],
            [:updated, 'updated'],
          ],
        )
      end

      it 'groups entries into non-empty sections' do
        expect(result.sections.map(&:first)).to eq(%i[added updated])
      end

      it 'counts changes by readable source, with all admin users in one group' do
        expect(result.counts_by_source).to eq(
          [
            described_class::SourceCount.new(
              source: 'Admin users',
              count: 3,
              breakdown: [described_class::AdminUserCount.new(label: 'Admin user', count: 3)],
            ),
            described_class::SourceCount.new(source: 'FPO CSV import', count: 1, breakdown: []),
          ],
        )
      end

      it 'builds the CSV from the same entries' do
        csv = CSV.parse(result.csv_data, headers: true)

        expect(csv.map { |row| row['Title'] }).to eq(['start of period', 'to update', 'end of period', 'updated'])
      end

      it 'names the file after the period' do
        expect(result.filename).to eq("search_reference_changes_#{TradeTariffBackend.service}_2026_10.csv")
      end

      it { expect(result.period_label).to eq('October 2026') }
      it { expect(result.total).to eq(4) }
      it { expect(result).not_to be_no_changes }
    end

    context 'when admin versions store user names' do
      before do
        create_reference_at(Time.utc(2026, 10, 2), title: 'no name yet')
        create_reference_at(Time.utc(2026, 10, 3), title: 'old name', whodunnit_name: 'Jane Smith')
        create_reference_at(Time.utc(2026, 10, 20), title: 'new name', whodunnit_name: 'Jane Jones')
        create_reference_at(Time.utc(2026, 10, 4), title: 'other user', whodunnit: other_admin_uid)
      end

      let(:breakdown) { result.counts_by_source.first.breakdown }

      it 'shows the newest name in the period for each admin user, and "Admin user" when there is no name' do
        expect(breakdown.map { |admin_user| [admin_user.label, admin_user.count] }).to eq(
          [['Jane Jones', 3], ['Admin user', 1]],
        )
      end

      it 'shows the name stored on each version in the CSV, and "Admin user" when there is no name' do
        csv = CSV.parse(result.csv_data, headers: true)

        expect(csv.to_h { |row| [row['Title'], row['Changed by']] }).to eq(
          'no name yet' => 'Admin user',
          'old name' => 'Jane Smith',
          'other user' => 'Admin user',
          'new name' => 'Jane Jones',
        )
      end

      it 'does not add the admin user ID to the CSV' do
        expect(result.csv_data).not_to include(admin_uid, other_admin_uid)
      end
    end

    context 'when there are no changes in the period' do
      it { expect(result).to be_no_changes }
      it { expect(result.csv_data.lines.size).to eq(1) }
    end

    context 'when running in production' do
      include_context 'with a stubbed reporting bucket'

      let(:persistence_bucket) { Rails.application.config.persistence_bucket }

      before do
        allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('production'))
        persistence_bucket.client.setup_stubbing
        persistence_bucket.client.stub_responses(:put_object)
        persistence_bucket.client.api_requests.clear
      end

      it 'uploads the CSV to the private persistence bucket' do
        result

        expect(persistence_bucket.client.api_requests).to include(
          hash_including(
            operation_name: :put_object,
            params: hash_including(
              bucket: persistence_bucket.name,
              key: described_class.object_key,
              body: result.csv_data,
              content_type: 'text/csv',
            ),
          ),
        )
      end

      it 'does not upload anything to the public reporting bucket' do
        result

        expect(s3_bucket.client.api_requests).to be_empty
      end
    end
  end
end
