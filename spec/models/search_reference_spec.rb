describe SearchReference do
  describe '#referenced' do
    context 'matching heading regexp' do
      let(:heading) { create :heading, goods_nomenclature_item_id: '1212000000' }
      let(:search_reference) { create :search_reference, referenced: heading }

      it 'returns referenced Heading object' do
        heading

        expect(search_reference.referenced).to eq heading
      end
    end

    context 'matching Chapter regexp' do
      let(:chapter) { create :chapter, goods_nomenclature_item_id: '1200000000' }
      let(:search_reference) { create :search_reference, referenced: chapter }

      it 'returns Chapter object' do
        chapter

        expect(search_reference.referenced).to eq chapter
      end
    end

    context 'matching Seciont regexp' do
      let(:section)          { create :section, position: 12 }
      let(:search_reference) { create :search_reference, referenced: section }

      it 'returns Section object' do
        section

        expect(search_reference.referenced).to eq section
      end
    end
  end
end
