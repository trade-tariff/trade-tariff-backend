RSpec.describe Chapter do
  describe 'Associations' do
    context 'with headings' do
      let!(:chapter)  { create :chapter }

      let!(:heading1) do
        create :heading, goods_nomenclature_item_id: "#{chapter.goods_nomenclature_item_id.first(2)}10000000",
                         validity_start_date: 10.years.ago,
                         validity_end_date: nil
      end
      let!(:heading2) do
        create :heading, goods_nomenclature_item_id: "#{chapter.goods_nomenclature_item_id.first(2)}20000000",
                         validity_start_date: 2.years.ago,
                         validity_end_date: nil
      end
      let!(:heading3) do
        create :heading, goods_nomenclature_item_id: "#{chapter.goods_nomenclature_item_id.first(2)}30000000",
                         validity_start_date: 10.years.ago,
                         validity_end_date: 8.years.ago
      end
      let!(:heading4) do
        create :heading, goods_nomenclature_item_id: "#{chapter.goods_nomenclature_item_id.first(2)}40000000",
                         validity_start_date: 10.years.ago,
                         validity_end_date: nil
      end

      before do
        # Hidden goods nomenclature
        create :hidden_goods_nomenclature, goods_nomenclature_item_id: heading4.goods_nomenclature_item_id
      end

      around do |example|
        TimeMachine.at(1.year.ago) do
          example.run
        end
      end

      it 'returns headings matched by part of own goods nomenclature item id' do
        expect(chapter.headings).to include heading1
      end

      it 'returns relevant by actual time headings' do
        expect(chapter.headings).to include heading2
      end

      it 'does not return heading that is irrelevant to given time' do
        expect(chapter.headings).not_to include heading3
      end

      it 'does not include hidden commodity' do
        expect(chapter.headings).not_to include heading4
      end
    end
  end

  describe '#number_indents' do
    let(:chapter) { build :chapter }

    it 'defaults to zero' do
      expect(chapter.number_indents).to eq 0
    end
  end

  describe '#customs_tariff_chapter_note' do
    let!(:chapter) { create(:chapter, goods_nomenclature_item_id: '0100000000') }

    around { |example| TimeMachine.now { example.run } }

    it 'returns the approved note from the currently actual update' do
      older = create(:customs_tariff_update, :approved, validity_start_date: 1.month.ago, validity_end_date: 1.day.ago)
      newer = create(:customs_tariff_update, :approved, validity_start_date: Time.zone.today)
      create(:customs_tariff_chapter_note, :approved, customs_tariff_update: older, chapter_id: chapter.short_code)
      note = create(:customs_tariff_chapter_note, :approved, customs_tariff_update: newer, chapter_id: chapter.short_code)

      expect(chapter.customs_tariff_chapter_note.id).to eq(note.id)
    end

    it 'ignores pending notes' do
      update = create(:customs_tariff_update, :approved)
      create(:customs_tariff_chapter_note, customs_tariff_update: update, chapter_id: chapter.short_code)

      expect(chapter.customs_tariff_chapter_note).to be_nil
    end
  end

  describe '#public_chapter_note' do
    let!(:chapter) { create(:chapter, goods_nomenclature_item_id: '0100000000') }
    let!(:legacy_note) { create(:chapter_note, chapter_id: chapter.short_code, content: 'Legacy chapter note') }
    let!(:customs_tariff_update) { create(:customs_tariff_update, :approved) }
    let!(:customs_tariff_note) do
      create(:customs_tariff_chapter_note, :approved,
             customs_tariff_update:,
             chapter_id: chapter.short_code,
             content: 'Imported chapter note')
    end

    context 'when promoted notes are enabled' do
      before do
        allow(TradeTariffBackend).to receive(:promote_customs_tariff_notes?).and_return(true)
      end

      it 'returns the customs tariff note' do
        expect(chapter.public_chapter_note).to eq(customs_tariff_note)
      end
    end

    context 'when promoted notes are disabled' do
      before do
        allow(TradeTariffBackend).to receive(:promote_customs_tariff_notes?).and_return(false)
      end

      it 'returns the legacy note' do
        expect(chapter.public_chapter_note).to eq(legacy_note)
      end
    end
  end

  describe '#to_param' do
    let(:chapter) { create :chapter, goods_nomenclature_item_id: '1200000000' }

    it 'returns short_code' do
      expect(chapter.to_param).to eq(chapter.short_code)
    end
  end

  describe '#changes' do
    let(:chapter) { create :chapter }

    it 'returns Sequel Dataset' do
      expect(chapter.changes).to be_a Sequel::Dataset
    end

    context 'with Chapter changes' do
      let!(:chapter) { create :chapter, operation_date: Time.zone.today }

      it 'includes Chapter changes' do
        expect(
          chapter.changes.select do |change|
            change.oid == chapter.oid &&
            change.model == described_class
          end,
        ).to be_present
      end

      context 'with Heading changes' do
        let!(:heading) do
          create :heading,
                 operation_date: Time.zone.today,
                 goods_nomenclature_item_id: "#{chapter.short_code}01000000"
        end

        it 'includes Heading changes' do
          expect(
            chapter.changes.select do |change|
              change.oid == heading.oid &&
              change.model == Heading
            end,
          ).to be_present
        end

        context 'with associated Commodity changes' do
          let!(:commodity) do
            create :commodity,
                   operation_date: Time.zone.today,
                   goods_nomenclature_item_id: "#{heading.short_code}000001"
          end

          it 'includes Commodity changes' do
            expect(
              chapter.changes.select do |change|
                change.oid == commodity.oid &&
                change.model == Commodity
              end,
            ).to be_present
          end

          context 'with associated Measure (through Commodity) changes' do
            let!(:measure) do
              create :measure,
                     goods_nomenclature: commodity,
                     goods_nomenclature_item_id: commodity.goods_nomenclature_item_id,
                     operation_date: Time.zone.today
            end

            it 'includes Measure changes' do
              expect(
                heading.changes.select do |change|
                  change.oid == measure.oid &&
                  change.model == Measure
                end,
              ).to be_present
            end
          end
        end
      end
    end
  end

  describe '.by_code' do
    let!(:chapter1) { create(:chapter, goods_nomenclature_item_id: '1200000000') }
    let!(:chapter2) { create(:chapter, goods_nomenclature_item_id: '2100000000') }

    it 'returns chapters filtered by goods_nomenclature_item_id', :aggregate_failures do
      chapters = described_class.by_code('12')
      expect(chapters).to include(chapter1)
      expect(chapters).not_to include(chapter2)
    end
  end

  describe 'first & last heading' do
    let(:chapter) { create :chapter, goods_nomenclature_item_id: '1200000000' }
    let!(:heading1) do
      create :heading, goods_nomenclature_item_id: "#{chapter.goods_nomenclature_item_id.first(2)}10000000",
                       validity_end_date: nil
    end
    let!(:heading2) do
      create :heading, goods_nomenclature_item_id: "#{chapter.goods_nomenclature_item_id.first(2)}30000000",
                       validity_end_date: nil
    end

    before do
      create :heading, goods_nomenclature_item_id: "#{chapter.goods_nomenclature_item_id.first(2)}20000000", validity_end_date: nil
    end

    describe '#first_heading' do
      it 'returns first heading ordered by goods_nomenclature_item_id' do
        expect(chapter.first_heading).to eq(heading1)
      end
    end

    describe '#last_heading' do
      it 'returns last heading ordered by goods_nomenclature_item_id' do
        expect(chapter.last_heading).to eq(heading2)
      end
    end

    describe '#headings_from' do
      it 'returns first heading short_code' do
        expect(chapter.headings_from).to eq(heading1.short_code)
      end
    end

    describe '#headings_to' do
      it 'returns last heading short_code' do
        expect(chapter.headings_to).to eq(heading2.short_code)
      end
    end
  end

  describe '#short_code' do
    let!(:chapter) { create :chapter, goods_nomenclature_item_id: '1200000000' }

    it 'returns first 2 chars of goods_nomenclature_item_id' do
      expect(chapter.short_code).to eq('12')
    end
  end

  describe '#relevant_headings' do
    let!(:chapter) { create :chapter, goods_nomenclature_item_id: '1200000000' }

    it 'includes short_code' do
      expect(chapter.send(:relevant_headings)).to include(chapter.short_code)
    end

    it 'includes suffix __000000' do
      expect(chapter.send(:relevant_headings)).to include('__000000')
    end

    it 'has valid format' do
      expect(chapter.send(:relevant_headings)).to eq("#{chapter.short_code}__000000")
    end
  end

  describe '#relevant_goods_nomenclature' do
    let!(:chapter) { create :chapter, goods_nomenclature_item_id: '1200000000' }

    it 'includes short_code' do
      expect(chapter.send(:relevant_goods_nomenclature)).to include(chapter.short_code)
    end

    it 'includes suffix __000000' do
      expect(chapter.send(:relevant_goods_nomenclature)).to include('________')
    end

    it 'has valid format' do
      expect(chapter.send(:relevant_goods_nomenclature)).to eq("#{chapter.short_code}________")
    end
  end

  describe '#goods_nomenclature_class' do
    subject { build(:chapter).goods_nomenclature_class }

    it { is_expected.to eq('Chapter') }
  end
end
