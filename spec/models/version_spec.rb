RSpec.describe Version do
  describe '#reify' do
    it 'constructs an unsaved instance from the snapshot' do
      note = create :section_note, content: 'original'
      note.update(content: 'updated')

      version = note.versions.first
      reified = version.reify

      expect(reified).to be_a(SectionNote)
      expect(reified.content).to eq('original')
      expect(reified).to be_new
    end

    it 'works with natural primary keys' do
      commodity = create :commodity
      label = create :goods_nomenclature_label, goods_nomenclature: commodity

      version = label.versions.first
      reified = version.reify

      expect(reified).to be_a(GoodsNomenclatureLabel)
      expect(reified.goods_nomenclature_sid).to eq(label.goods_nomenclature_sid)
    end
  end

  describe '#previous_version' do
    it 'returns the preceding version for the same item' do
      note = create :section_note, content: 'v1'
      note.update(content: 'v2')
      note.update(content: 'v3')

      versions = note.versions.order(:id).all
      expect(versions[2].previous_version).to eq(versions[1])
      expect(versions[1].previous_version).to eq(versions[0])
      expect(versions[0].previous_version).to be_nil
    end
  end

  describe '#changeset' do
    it 'returns nil for create events' do
      note = create :section_note, content: 'original'
      version = note.versions.first

      expect(version.event).to eq('create')
      expect(version.changeset).to be_nil
    end

    it 'returns a diff for update events' do
      note = create :section_note, content: 'A' * 50
      note.update(content: 'B' * 50)

      version = note.versions.order(:id).last

      expect(version.event).to eq('update')
      expect(version.changeset).to be_a(Hash)
      expect(version.changeset['changed_fields']).to include('content')
    end
  end

  describe '.preload_predecessors' do
    it 'batch-loads predecessors to avoid N+1' do
      note = create :section_note, content: 'v1'
      note.update(content: 'v2')
      note.update(content: 'v3')

      versions = note.versions.order(Sequel.desc(:id)).all
      described_class.preload_predecessors(versions)

      # The most recent version (v3) should have v2 as predecessor
      expect(versions[0].previous_version.object['content']).to eq('v2')
      # v2 should have v1 as predecessor
      expect(versions[1].previous_version.object['content']).to eq('v1')
      # v1 (create) should have no predecessor
      expect(versions[2].previous_version).to be_nil
    end

    it 'finds predecessors excluded by event filtering' do
      note = create :section_note, content: 'v1'
      note.update(content: 'v2')

      # Simulate event-filtered page: only the update version is in the batch
      update_version = note.versions.where(event: 'update').first
      described_class.preload_predecessors([update_version])

      expect(update_version.previous_version).not_to be_nil
      expect(update_version.previous_version.event).to eq('create')
    end
  end
end
