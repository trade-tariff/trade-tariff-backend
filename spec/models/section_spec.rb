RSpec.describe Section do
  describe 'default ordering' do
    subject { described_class.all.pluck(:position) }

    before do
      create :section, position: 3, title: 'Section 3'
      create :section, position: 2, title: 'Section 2'
      create :section, position: 1, title: 'Section 1'
    end

    it { is_expected.to eql [1, 2, 3] }
  end

  describe 'associations' do
    describe 'chapters' do
      let!(:chapter) { create(:chapter, :with_section) }

      it 'does not include HiddenGoodsNomenclatures' do
        section = chapter.section
        create(:hidden_goods_nomenclature, goods_nomenclature_item_id: chapter.goods_nomenclature_item_id)

        expect(section.chapters).to eq []
      end
    end
  end

  describe '#current_customs_tariff_section_note' do
    let!(:section) { create(:section) }

    around { |example| TimeMachine.now { example.run } }

    it 'returns the note from the currently actual update' do
      older = create(:customs_tariff_update, validity_start_date: 1.month.ago, validity_end_date: 1.day.ago)
      newer = create(:customs_tariff_update, validity_start_date: Time.zone.today)
      create(:customs_tariff_section_note, customs_tariff_update: older, section_id: section.id)
      note = create(:customs_tariff_section_note, customs_tariff_update: newer, section_id: section.id)

      expect(section.current_customs_tariff_section_note.id).to eq(note.id)
    end

    it 'returns nil when no note exists for this section' do
      create(:customs_tariff_update)
      expect(section.current_customs_tariff_section_note).to be_nil
    end
  end

  describe '#customs_tariff_section_note' do
    let!(:section) { create(:section) }

    around { |example| TimeMachine.now { example.run } }

    it 'returns the note from the currently actual non-failed update' do
      older = create(:customs_tariff_update, validity_start_date: 1.month.ago, validity_end_date: 1.day.ago)
      newer = create(:customs_tariff_update, validity_start_date: Time.zone.today)
      create(:customs_tariff_section_note, customs_tariff_update: older, section_id: section.id)
      note = create(:customs_tariff_section_note, customs_tariff_update: newer, section_id: section.id)

      expect(section.customs_tariff_section_note.id).to eq(note.id)
    end

    it 'returns pending notes' do
      update = create(:customs_tariff_update)
      note = create(:customs_tariff_section_note, customs_tariff_update: update, section_id: section.id)

      expect(section.customs_tariff_section_note.id).to eq(note.id)
    end

    it 'ignores notes from failed updates' do
      failed_update = create(:customs_tariff_update, :failed, validity_start_date: Time.zone.today)
      create(:customs_tariff_section_note, customs_tariff_update: failed_update, section_id: section.id)

      expect(section.customs_tariff_section_note).to be_nil
    end
  end

  describe '#public_section_note' do
    let!(:section) { create(:section) }
    let!(:legacy_note) { create(:section_note, section_id: section.id, content: 'Legacy section note') }
    let!(:customs_tariff_update) { create(:customs_tariff_update, :approved) }
    let!(:customs_tariff_note) do
      create(:customs_tariff_section_note, :approved,
             customs_tariff_update:,
             section_id: section.id,
             content: 'Imported section note')
    end

    context 'when promoted notes are enabled' do
      before do
        allow(TradeTariffBackend).to receive(:promote_customs_tariff_notes?).and_return(true)
      end

      it 'returns the customs tariff note' do
        expect(section.public_section_note).to eq(customs_tariff_note)
      end
    end

    context 'when promoted notes are disabled' do
      before do
        allow(TradeTariffBackend).to receive(:promote_customs_tariff_notes?).and_return(false)
      end

      it 'returns the legacy note' do
        expect(section.public_section_note).to eq(legacy_note)
      end
    end
  end
end
