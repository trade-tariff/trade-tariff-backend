RSpec.describe TariffKnowledge::NoteMarkerClassifier do
  describe '.call' do
    def fragment(key, content)
      Data.define(:key, :content).new(key, content)
    end

    it 'classifies markdown headings' do
      event = described_class.call(fragment('f1', '### Subheading notes'))

      expect(event).to have_attributes(
        kind: :heading,
        marker: 'subheading_notes',
        depth: 0,
        path_segment: 'subheading_notes',
        title: 'Subheading notes',
        body: '',
      )
    end

    it 'classifies numeric markers with trailing body' do
      event = described_class.call(fragment('f1', '1. In this chapter, the following expressions have meanings:'))

      expect(event).to have_attributes(
        kind: :numeric,
        marker: '1',
        depth: 1,
        path_segment: '1',
        title: '1',
        body: 'In this chapter, the following expressions have meanings:',
      )
    end

    it 'classifies definition-like alpha markers' do
      event = described_class.call(fragment('f2', 'a. pig Iron'))

      expect(event).to have_attributes(
        kind: :alpha,
        marker: 'a',
        depth: 2,
        path_segment: 'a',
        title: 'pig Iron',
        body: '',
      )
    end

    it 'classifies single-letter roman-looking markers as alpha definitions' do
      event = described_class.call(fragment('f2', 'i. insulating materials'))

      expect(event).to have_attributes(
        kind: :alpha,
        marker: 'i',
        depth: 2,
        path_segment: 'i',
        title: 'insulating materials',
        body: '',
      )
    end

    it 'reattaches compact marker suffixes to the body' do
      event = described_class.call(fragment('f2', '1.foo bar'))

      expect(event).to have_attributes(
        kind: :numeric,
        marker: '1',
        depth: 1,
        path_segment: '1',
        title: '1',
        body: 'foo bar',
      )
    end

    it 'does not classify decimals as compact marker prefixes' do
      event = described_class.call(fragment('f2', '1.23 % by weight'))

      expect(event).to have_attributes(
        kind: :continuation,
        marker: nil,
        depth: nil,
        title: nil,
        body: '1.23 % by weight',
      )
    end

    it 'does not classify abbreviations as compact marker prefixes' do
      event = described_class.call(fragment('f2', 'i.e. examples'))

      expect(event).to have_attributes(
        kind: :continuation,
        marker: nil,
        depth: nil,
        title: nil,
        body: 'i.e. examples',
      )
    end

    it 'does not classify compact alpha prefixes' do
      event = described_class.call(fragment('f2', 'a.foo bar'))

      expect(event).to have_attributes(
        kind: :continuation,
        marker: nil,
        body: 'a.foo bar',
      )
    end

    it 'does not classify compact roman prefixes' do
      event = described_class.call(fragment('f2', 'ii.foo bar'))

      expect(event).to have_attributes(
        kind: :continuation,
        marker: nil,
        body: 'ii.foo bar',
      )
    end

    it 'classifies uppercase markers case-insensitively' do
      event = described_class.call(fragment('f2', 'A. The following'))

      expect(event).to have_attributes(
        kind: :alpha,
        marker: 'a',
        depth: 2,
        path_segment: 'a',
        title: 'The following',
        body: '',
      )
    end

    it 'classifies bullets without treating them as definitions' do
      event = described_class.call(fragment('f3', '- not more than 10 % of chromium'))

      expect(event).to have_attributes(
        kind: :bullet,
        marker: '-',
        depth: 4,
        title: nil,
        body: 'not more than 10 % of chromium',
      )
    end

    it 'classifies unmatched text as continuation' do
      event = described_class.call(fragment('f4', 'Iron-carbon alloys not usefully malleable.'))

      expect(event).to have_attributes(
        kind: :continuation,
        marker: nil,
        depth: nil,
        title: nil,
        body: 'Iron-carbon alloys not usefully malleable.',
      )
    end
  end
end
