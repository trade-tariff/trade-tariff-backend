RSpec.describe TariffKnowledge::NoteMarkerTrie do
  describe '#match' do
    it 'classifies exact marker tokens by longest registered match' do
      trie = described_class.default

      expect(trie.match('ij.')).to have_attributes(kind: :alpha, marker: 'ij')
      expect(trie.match('ii.')).to have_attributes(kind: :roman, marker: 'ii')
      expect(trie.match('(a)')).to have_attributes(kind: :alpha, marker: 'a')
      expect(trie.match('—')).to have_attributes(kind: :bullet, marker: '—')
    end

    it 'classifies single-letter roman-looking tokens as alpha markers' do
      trie = described_class.default

      expect(trie.match('i.')).to have_attributes(kind: :alpha, marker: 'i')
      expect(trie.match('v.')).to have_attributes(kind: :alpha, marker: 'v')
      expect(trie.match('x.')).to have_attributes(kind: :alpha, marker: 'x')
    end

    it 'classifies parenthesized and suffix single-letter roman tokens as roman markers' do
      trie = described_class.default

      expect(trie.match('(i)')).to have_attributes(kind: :roman, marker: 'i')
      expect(trie.match('i)')).to have_attributes(kind: :roman, marker: 'i')
      expect(trie.match('(v)')).to have_attributes(kind: :roman, marker: 'v')
      expect(trie.match('v)')).to have_attributes(kind: :roman, marker: 'v')
      expect(trie.match('(x)')).to have_attributes(kind: :roman, marker: 'x')
      expect(trie.match('x)')).to have_attributes(kind: :roman, marker: 'x')
    end

    it 'classifies multi-letter roman tokens as roman markers' do
      trie = described_class.default

      expect(trie.match('ii.')).to have_attributes(kind: :roman, marker: 'ii')
      expect(trie.match('iv.')).to have_attributes(kind: :roman, marker: 'iv')
      expect(trie.match('xii.')).to have_attributes(kind: :roman, marker: 'xii')
    end

    it 'classifies the longest registered prefix before prose starts' do
      expect(described_class.default.match('1.foo')).to have_attributes(kind: :numeric, marker: '1')
    end

    it 'returns nil for prose that is not a registered marker' do
      expect(described_class.default.match('Iron-carbon')).to be_nil
    end
  end
end
