RSpec.describe Search::GoodsNomenclatureSerializer do
  around { |example| TimeMachine.now { example.run } }

  describe '#serializable_hash' do
    subject(:result) { described_class.new(commodity).serializable_hash }

    let(:commodity) do
      create(:commodity, :with_ancestors, :with_description,
             goods_nomenclature_item_id: '0101210000',
             description: 'Live horses, other than pure-bred breeding animals')
    end

    it 'includes presentational fields' do
      expect(result).to include(
        goods_nomenclature_sid: commodity.goods_nomenclature_sid,
        goods_nomenclature_item_id: '0101210000',
        producline_suffix: commodity.producline_suffix,
        declarable: commodity.declarable?,
        goods_nomenclature_class: commodity.goods_nomenclature_class,
      )
    end

    it 'includes chapter and heading short codes' do
      expect(result).to include(
        chapter_short_code: commodity.chapter_short_code,
        heading_short_code: commodity.heading_short_code,
      )
    end

    it 'includes the formatted description for display' do
      expect(result[:formatted_description]).to be_present
    end

    it 'includes description passed through SearchNegationService' do
      expect(result[:description]).to be_present
      expect(result[:description]).not_to include('other than')
    end

    it 'includes ancestor descriptions for search context' do
      expect(result[:ancestor_descriptions]).to be_a(String)
    end

    context 'with search references' do
      before do
        create(:search_reference,
               referenced: commodity,
               title: 'ponies, excluding miniature')
      end

      it 'includes search reference titles with negation removed' do
        commodity.reload
        result = described_class.new(commodity).serializable_hash

        expect(result[:search_references]).to be_present
        expect(result[:search_references].first).not_to include('excluding')
      end
    end

    context 'with labels' do
      before do
        create(:goods_nomenclature_label,
               goods_nomenclature_sid: commodity.goods_nomenclature_sid,
               goods_nomenclature_item_id: commodity.goods_nomenclature_item_id,
               producline_suffix: commodity.producline_suffix,
               goods_nomenclature_type: 'Commodity',
               labels: {
                 'description' => 'Live horses for riding or racing',
                 'known_brands' => [],
                 'colloquial_terms' => %w[horses ponies],
                 'synonyms' => ['equine animals'],
               })
        commodity.reload
      end

      it 'includes label data' do
        result = described_class.new(commodity).serializable_hash

        expect(result[:labels]).to include(
          description: 'Live horses for riding or racing',
          colloquial_terms: %w[horses ponies],
          synonyms: ['equine animals'],
        )
      end

      it 'omits empty label fields' do
        result = described_class.new(commodity).serializable_hash

        expect(result[:labels]).not_to have_key(:known_brands)
      end
    end

    context 'without labels' do
      it 'does not include labels key' do
        expect(result[:labels]).to be_nil
      end
    end

    describe '#full_description' do
      before do
        SelfTextLookupService.instance_variable_set(:@self_texts, nil)
      end

      context 'when self-text is available' do
        before do
          allow(SelfTextLookupService).to receive(:lookup)
            .with(commodity.goods_nomenclature_item_id)
            .and_return('CN2026 self-text for horses')
        end

        it 'uses self-text for full_description' do
          expect(result[:full_description]).to eq('CN2026 self-text for horses')
        end

        it 'passes self-text through SearchNegationService for description' do
          expect(result[:description]).to eq('CN2026 self-text for horses')
        end
      end

      context 'when self-text is not available' do
        before do
          allow(SelfTextLookupService).to receive(:lookup).and_return(nil)
        end

        it 'uses classification_description for full_description' do
          expect(result[:full_description]).to eq(commodity.classification_description)
        end
      end

      context 'when self-text is blank' do
        before do
          allow(SelfTextLookupService).to receive(:lookup).and_return('')
        end

        it 'falls back to classification_description' do
          expect(result[:full_description]).to eq(commodity.classification_description)
        end
      end
    end

    describe '#heading_description' do
      it 'returns the heading formatted_description' do
        expect(result[:heading_description]).to eq(commodity.heading&.formatted_description)
      end

      context 'when commodity has no heading' do
        let(:commodity) do
          create(:chapter, :with_description,
                 goods_nomenclature_item_id: '0100000000',
                 description: 'Live animals')
        end

        it 'returns nil' do
          expect(result[:heading_description]).to be_nil
        end
      end
    end
  end
end
