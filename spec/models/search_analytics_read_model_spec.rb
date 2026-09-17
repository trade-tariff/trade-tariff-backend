# frozen_string_literal: true

RSpec.describe SearchAnalyticsReadModel do
  let(:now) { Time.utc(2026, 9, 15, 10, 11, 12.123456) }
  let(:first_date) { Date.new(2026, 9, 13) }
  let(:last_date) { Date.new(2026, 9, 14) }
  let(:record) do
    Data.define(:name, :reporting_date, :fingerprint, :collected_at, :id)
  end

  describe '.versions' do
    it 'groups selected source names by date and ignores other query groups' do
      rows = [
        record.new('volume', first_date, 'volume-fp', now, 1),
        record.new('journey_outcomes', last_date, 'out-b', now, 4),
        record.new('search_journeys', last_date, 'jny-b', now, 3),
        record.new('search_journeys', first_date, 'jny-a', now, 2),
      ]

      expect(described_class.versions(rows)).to eq(
        first_date.iso8601 => [['search_journeys', 'jny-a', now.iso8601(6), 2]],
        last_date.iso8601 => [
          ['journey_outcomes', 'out-b', now.iso8601(6), 4],
          ['search_journeys', 'jny-b', now.iso8601(6), 3],
        ],
      )
    end
  end

  describe '.latest' do
    it 'returns the newest generation for one service and region' do
      create(:search_analytics_read_model, service: 'uk', region: 'eu-west-2', built_at: now - 2.hours)
      newest = create(:search_analytics_read_model, service: 'uk', region: 'eu-west-2', built_at: now)
      create(:search_analytics_read_model, service: 'xi', region: 'eu-west-2', built_at: now + 1.hour)
      create(:search_analytics_read_model, service: 'uk', region: 'eu-west-1', built_at: now + 1.hour)

      expect(described_class.latest(service: 'uk', region: 'eu-west-2')).to eq(newest)
    end
  end

  describe '#compatible?' do # rubocop:disable RSpec/MultipleMemoizedHelpers
    let(:definitions) do
      { 'search_journeys' => 'jny', 'journey_outcomes' => 'out', 'volume' => 'vol' }
    end
    let(:records) do
      [
        record.new('search_journeys', last_date, 'jny', now, 8),
        record.new('volume', last_date, 'vol', now, 9),
      ]
    end
    let(:model) do
      create(
        :search_analytics_read_model,
        fingerprints: definitions.slice(*described_class::SOURCE_NAMES),
        source_versions: described_class.versions(records),
      )
    end

    it 'accepts matching version, source fingerprints and selected-date revisions' do
      expect(model.compatible?(records:, definitions:, dates: [last_date])).to be(true)
    end

    it 'ignores source days outside the selected dates' do
      extra = records + [record.new('search_journeys', first_date, 'jny', now, 10)]
      expect(model.compatible?(records: extra, definitions:, dates: [last_date])).to be(true)
    end

    it 'rejects a different processing version' do
      model.update(version: described_class::VERSION + 1)
      expect(model.compatible?(records:, definitions:, dates: [last_date])).to be(false)
    end

    it 'rejects a changed source fingerprint' do
      expect(model.compatible?(records:, definitions: definitions.merge('search_journeys' => 'changed'), dates: [last_date])).to be(false)
    end

    it 'rejects a changed selected-date revision' do
      changed = [record.new('search_journeys', last_date, 'jny', now + 1.second, 8)]
      expect(model.compatible?(records: changed, definitions:, dates: [last_date])).to be(false)
    end
  end
end
