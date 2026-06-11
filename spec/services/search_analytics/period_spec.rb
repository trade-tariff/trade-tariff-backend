RSpec.describe SearchAnalytics::Period do
  describe '.for' do
    it 'normalises 24h to an hourly 24 hour window' do
      period = described_class.for(period: '24h', view: 'all')

      expect(period.key).to eq('24h')
      expect(period.view).to eq('all')
      expect(period.duration).to eq(24.hours)
      expect(period.bucket_size).to eq('hour')
    end

    it 'normalises 7d to a daily 7 day window' do
      period = described_class.for(period: '7d', view: 'classic')

      expect(period.key).to eq('7d')
      expect(period.view).to eq('classic')
      expect(period.duration).to eq(7.days)
      expect(period.bucket_size).to eq('day')
    end

    it 'normalises 30d to a daily 30 day window' do
      period = described_class.for(period: '30d', view: 'internal')

      expect(period.key).to eq('30d')
      expect(period.view).to eq('internal')
      expect(period.duration).to eq(30.days)
      expect(period.bucket_size).to eq('day')
    end

    it 'falls back to 24h when the period is unknown' do
      period = described_class.for(period: 'invalid', view: 'all')

      expect(period.key).to eq('24h')
      expect(period.duration).to eq(24.hours)
      expect(period.bucket_size).to eq('hour')
    end

    it 'falls back to all when the view is unknown' do
      period = described_class.for(period: '24h', view: 'invalid')

      expect(period.view).to eq('all')
    end
  end
end
