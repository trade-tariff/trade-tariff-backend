RSpec.describe ChapterNote do
  describe '#chapter' do
    it 'returns the associated chapter' do
      chapter = create(:chapter, :chapter01)
      chapter_note = described_class.new(chapter_id: '01', content: 'Chapter note')

      allow(chapter_note).to receive(:chapter_goods_id).and_return('0100000000')

      expect(chapter_note.chapter).to eq(chapter)
    end
  end
end
