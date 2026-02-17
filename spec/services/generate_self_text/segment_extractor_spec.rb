RSpec.describe GenerateSelfText::SegmentExtractor do
  describe '.call' do
    subject(:segments) { described_class.call(chapter, self_texts:) }

    let(:self_texts) { {} }

    let(:chapter) { create(:chapter, :with_description, description: 'Live animals') }

    let(:heading) do
      create(:heading, :with_description,
             description: 'Live horses',
             parent: chapter)
    end

    let(:commodity_a) do
      create(:commodity, :with_description,
             description: 'Pure-bred breeding animals',
             parent: heading)
    end

    let(:commodity_b) do
      create(:commodity, :with_description,
             description: 'Other',
             parent: heading)
    end

    before do
      # Force creation of the tree
      commodity_a
      commodity_b
    end

    it 'returns segments ordered shallowest-first' do
      depths = segments.map { |s| ancestor_depth(s) }

      expect(depths).to eq(depths.sort)
    end

    it 'includes all nodes in the chapter hierarchy' do
      sids = segments.map { |s| s[:node][:sid] }

      expect(sids).to contain_exactly(
        chapter.goods_nomenclature_sid,
        heading.goods_nomenclature_sid,
        commodity_a.goods_nomenclature_sid,
        commodity_b.goods_nomenclature_sid,
      )
    end

    it 'returns the chapter segment with an empty ancestor chain' do
      chapter_segment = segment_for_sid(chapter.goods_nomenclature_sid)

      expect(chapter_segment[:ancestor_chain]).to eq([])
    end

    it 'returns the heading segment with chapter as ancestor' do
      heading_segment = segment_for_sid(heading.goods_nomenclature_sid)

      expect(heading_segment[:ancestor_chain]).to eq([
        { sid: chapter.goods_nomenclature_sid, description: 'Live animals', self_text: nil },
      ])
    end

    it 'returns commodity segments with full ancestor chain in root-to-parent order' do
      commodity_segment = segment_for_sid(commodity_a.goods_nomenclature_sid)

      expect(commodity_segment[:ancestor_chain]).to eq([
        { sid: chapter.goods_nomenclature_sid, description: 'Live animals', self_text: nil },
        { sid: heading.goods_nomenclature_sid, description: 'Live horses', self_text: nil },
      ])
    end

    context 'with "Other" detection' do
      it 'marks exact "Other" as is_other' do
        segment = segment_for_sid(commodity_b.goods_nomenclature_sid)

        expect(segment[:node][:is_other]).to be true
      end

      it 'marks non-Other descriptions as not is_other' do
        segment = segment_for_sid(commodity_a.goods_nomenclature_sid)

        expect(segment[:node][:is_other]).to be false
      end

      context 'when description is case-variant' do
        let(:commodity_b) do
          create(:commodity, :with_description,
                 description: 'OTHER',
                 parent: heading)
        end

        it 'matches case-insensitively' do
          segment = segment_for_sid(commodity_b.goods_nomenclature_sid)

          expect(segment[:node][:is_other]).to be true
        end
      end

      context 'when description is "Other than horses"' do
        let(:commodity_b) do
          create(:commodity, :with_description,
                 description: 'Other than horses',
                 parent: heading)
        end

        it 'does not match "Other than" exclusion phrases' do
          segment = segment_for_sid(commodity_b.goods_nomenclature_sid)

          expect(segment[:node][:is_other]).to be false
        end
      end

      context 'when description is "Other, fresh or chilled"' do
        let(:commodity_b) do
          create(:commodity, :with_description,
                 description: 'Other, fresh or chilled',
                 parent: heading)
        end

        it 'matches qualified Other with comma' do
          segment = segment_for_sid(commodity_b.goods_nomenclature_sid)

          expect(segment[:node][:is_other]).to be true
        end

        it 'populates siblings' do
          segment = segment_for_sid(commodity_b.goods_nomenclature_sid)

          expect(segment[:siblings].size).to eq(1)
        end
      end

      context 'when description is "Other (including factory rejects)"' do
        let(:commodity_b) do
          create(:commodity, :with_description,
                 description: 'Other (including factory rejects)',
                 parent: heading)
        end

        it 'matches qualified Other with parenthetical' do
          segment = segment_for_sid(commodity_b.goods_nomenclature_sid)

          expect(segment[:node][:is_other]).to be true
        end
      end

      context 'when description ends with ", other"' do
        let(:commodity_b) do
          create(:commodity, :with_description,
                 description: 'Of pine (pinus spp.), other',
                 parent: heading)
        end

        it 'matches trailing other' do
          segment = segment_for_sid(commodity_b.goods_nomenclature_sid)

          expect(segment[:node][:is_other]).to be true
        end
      end

      context 'when description is "Other live animals"' do
        let(:commodity_b) do
          create(:commodity, :with_description,
                 description: 'Other live animals',
                 parent: heading)
        end

        it 'matches residual Other with noun phrase' do
          segment = segment_for_sid(commodity_b.goods_nomenclature_sid)

          expect(segment[:node][:is_other]).to be true
        end

        it 'populates siblings' do
          segment = segment_for_sid(commodity_b.goods_nomenclature_sid)

          expect(segment[:siblings].size).to eq(1)
        end
      end

      context 'when description is "Other than for use in manufacturing"' do
        let(:commodity_b) do
          create(:commodity, :with_description,
                 description: 'Other than for use in manufacturing',
                 parent: heading)
        end

        it 'does not match "Other than" exclusion phrases' do
          segment = segment_for_sid(commodity_b.goods_nomenclature_sid)

          expect(segment[:node][:is_other]).to be false
        end
      end
    end

    context 'with sibling population' do
      it 'populates siblings for "Other" nodes' do
        segment = segment_for_sid(commodity_b.goods_nomenclature_sid)

        expect(segment[:siblings]).to eq([
          {
            sid: commodity_a.goods_nomenclature_sid,
            code: commodity_a.goods_nomenclature_item_id,
            description: 'Pure-bred breeding animals',
          },
        ])
      end

      it 'excludes self from siblings' do
        segment = segment_for_sid(commodity_b.goods_nomenclature_sid)
        sibling_sids = segment[:siblings].map { |s| s[:sid] }

        expect(sibling_sids).not_to include(commodity_b.goods_nomenclature_sid)
      end

      it 'returns empty siblings for non-Other nodes' do
        segment = segment_for_sid(commodity_a.goods_nomenclature_sid)

        expect(segment[:siblings]).to eq([])
      end
    end

    context 'with self_texts injected' do
      let(:self_texts) do
        { chapter.goods_nomenclature_sid => 'Chapter self text' }
      end

      it 'includes self_text in ancestor chain entries' do
        heading_segment = segment_for_sid(heading.goods_nomenclature_sid)

        expect(heading_segment[:ancestor_chain].first[:self_text]).to eq('Chapter self text')
      end

      it 'returns nil self_text for ancestors without injected self-texts' do
        commodity_segment = segment_for_sid(commodity_a.goods_nomenclature_sid)
        heading_ancestor = commodity_segment[:ancestor_chain].last

        expect(heading_ancestor[:self_text]).to be_nil
      end
    end

    context 'with null bytes in descriptions' do
      it 'strips null bytes from descriptions' do
        extractor = described_class.new(chapter)
        result = extractor.send(:sanitise, "Live horses\u0000with nulls\u0000")

        expect(result).to eq('Live horseswith nulls')
      end

      it 'handles nil descriptions' do
        extractor = described_class.new(chapter)

        expect(extractor.send(:sanitise, nil)).to be_nil
      end
    end

    context 'with a chapter that has no descendants' do
      let(:chapter) { create(:chapter, :with_description, description: 'Empty chapter') }
      let(:heading) { nil }
      let(:commodity_a) { nil }
      let(:commodity_b) { nil }

      it 'returns a single segment for the chapter' do
        expect(segments.size).to eq(1)
        expect(segments.first[:node][:sid]).to eq(chapter.goods_nomenclature_sid)
        expect(segments.first[:ancestor_chain]).to eq([])
      end
    end

    context 'with a deeper hierarchy' do
      let(:subheading) do
        create(:goods_nomenclature, :with_description,
               description: 'Horses for breeding',
               parent: heading)
      end

      let(:deep_commodity) do
        create(:commodity, :with_description,
               description: 'Stallions',
               parent: subheading)
      end

      before do
        subheading
        deep_commodity
      end

      it 'walks the full ancestor chain' do
        segment = segment_for_sid(deep_commodity.goods_nomenclature_sid)

        expect(segment[:ancestor_chain].map { |a| a[:sid] }).to eq([
          chapter.goods_nomenclature_sid,
          heading.goods_nomenclature_sid,
          subheading.goods_nomenclature_sid,
        ])
      end
    end

    def segment_for_sid(sid)
      segments.find { |s| s[:node][:sid] == sid }
    end

    def ancestor_depth(segment)
      segment[:ancestor_chain].size
    end
  end
end
