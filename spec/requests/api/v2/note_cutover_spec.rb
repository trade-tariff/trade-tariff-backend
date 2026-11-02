RSpec.describe 'Section and chapter note cutover', :v2 do
  let(:migration) do
    load Rails.root.join('db/data_migrations/20261102120000_preserve_legacy_notes_before_extraction_cutover.rb')
    Sequel::Migration.descendants.pop
  end
  let!(:chapter) do
    create(:chapter, :with_section, goods_nomenclature_item_id: '0100000000',
                                    validity_start_date: Date.new(1972, 1, 1))
  end
  let(:section) { chapter.section }
  let!(:current_update) { create(:customs_tariff_update, validity_start_date: Date.new(2026, 10, 1)) }

  before do
    create(:chapter_note, chapter_id: chapter.short_code, content: 'Legacy chapter')
    create(:section_note, section_id: section.id, content: 'Legacy section')
    create(:customs_tariff_chapter_note,
           customs_tariff_update: current_update, chapter_id: chapter.short_code, content: 'Extracted chapter')
    create(:customs_tariff_section_note,
           customs_tariff_update: current_update, section_id: section.id, content: 'Extracted section')
    allow(TradeTariffBackend).to receive(:promote_customs_tariff_notes?).and_return(true)
  end

  [
    %w[1972-01-01 Legacy],
    %w[2026-11-03 Legacy],
    %w[2026-11-04 Extracted],
    %w[2026-11-05 Extracted],
  ].each do |date, source|
    it "returns #{source.downcase} notes on #{date}" do
      migration.apply(Sequel::Model.db, :up)

      api_get "/#{TradeTariffBackend.service}/api/chapters/#{chapter.short_code}", params: { as_of: date }

      expect(response).to have_http_status(:ok)
      chapter_body = JSON.parse(response.body)
      expect(chapter_body.dig('data', 'attributes', 'chapter_note')).to eq("#{source} chapter")
      expect(chapter_body.fetch('included').find { |item| item['type'] == 'section' }
                         .dig('attributes', 'section_note')).to eq("#{source} section")

      api_get "/#{TradeTariffBackend.service}/api/sections/#{section.position}", params: { as_of: date }

      expect(response).to have_http_status(:ok)
      section_body = JSON.parse(response.body)
      expect(section_body.dig('data', 'attributes', 'section_note')).to eq("#{source} section")
    end
  end

  it 'preserves future note versions' do
    future = create(:customs_tariff_update, validity_start_date: Date.new(2027, 1, 1))
    create(:customs_tariff_chapter_note,
           customs_tariff_update: future, chapter_id: chapter.short_code, content: 'Future chapter')
    create(:customs_tariff_section_note,
           customs_tariff_update: future, section_id: section.id, content: 'Future section')

    migration.apply(Sequel::Model.db, :up)

    TimeMachine.at('2027-01-01') do
      expect(chapter.refresh.public_chapter_note.content).to eq('Future chapter')
      expect(section.refresh.public_section_note.content).to eq('Future section')
    end
  end

  it 'removes superseded notes, not source documents or general rules' do
    older = create(:customs_tariff_update, validity_start_date: Date.new(2026, 1, 1))
    create(:customs_tariff_chapter_note, customs_tariff_update: older, chapter_id: chapter.short_code)
    create(:customs_tariff_section_note, customs_tariff_update: older, section_id: section.id)
    rule = create(:customs_tariff_general_rule, customs_tariff_update: older)
    original_update = current_update.values.dup

    migration.apply(Sequel::Model.db, :up)

    expect(CustomsTariffChapterNote.where(customs_tariff_update_version: older.version)).to be_empty
    expect(CustomsTariffSectionNote.where(customs_tariff_update_version: older.version)).to be_empty
    expect(older.exists?).to be true
    expect(rule.exists?).to be true
    expect(current_update.refresh.values).to eq(original_update)
  end

  it 'keeps the original snapshot on reruns' do
    migration.apply(Sequel::Model.db, :up)
    chapters = CustomsTariffChapterNote.order(:id).all.map(&:values)
    sections = CustomsTariffSectionNote.order(:id).all.map(&:values)
    ChapterNote.first.update(content: 'Later legacy edit')
    SectionNote.first.update(content: 'Later legacy edit')

    migration.apply(Sequel::Model.db, :up)

    expect(CustomsTariffChapterNote.order(:id).all.map(&:values)).to eq(chapters)
    expect(CustomsTariffSectionNote.order(:id).all.map(&:values)).to eq(sections)
  end

  it 'migrates XI independently of UK' do
    db = Sequel::Model.db
    tables = %i[customs_tariff_updates customs_tariff_chapter_notes customs_tariff_section_notes chapter_notes section_notes]
    db.create_schema(:note_cutover_xi)
    tables.each do |table|
      db.run("CREATE TABLE note_cutover_xi.#{table} (LIKE uk.#{table} INCLUDING ALL)")
      columns = db.schema(Sequel[:uk][table]).map(&:first) - [:id]
      db[Sequel[:note_cutover_xi][table]].insert(columns, db[Sequel[:uk][table]].select(*columns))
    end
    db[Sequel[:note_cutover_xi][:chapter_notes]].update(content: 'XI legacy chapter')
    db[Sequel[:note_cutover_xi][:section_notes]].update(content: 'XI legacy section')
    original_updates = CustomsTariffUpdate.all.map(&:values)
    allow(TradeTariffBackend).to receive_messages(service: 'xi', uk?: false, xi?: true)

    begin
      db.run('SET LOCAL search_path TO note_cutover_xi, public')
      migration.apply(db, :up)

      TimeMachine.at('2026-11-03 23:59:59') do
        expect(CustomsTariffChapterNote.actual.first.content).to eq('XI legacy chapter')
        expect(CustomsTariffSectionNote.actual.first.content).to eq('XI legacy section')
      end
    ensure
      db.run('SET LOCAL search_path TO uk, public')
    end

    expect(CustomsTariffUpdate.all.map(&:values)).to eq(original_updates)
    expect(CustomsTariffChapterNote.count).to eq(1)
    expect(CustomsTariffSectionNote.count).to eq(1)
  end

  it 'stops without changing data if extraction is missing' do
    CustomsTariffSectionNote.where(customs_tariff_update_version: current_update.version).delete

    expect { migration.apply(Sequel::Model.db, :up) }.to raise_error(/Cannot migrate notes/)
    expect(CustomsTariffChapterNote.first.validity_start_date).to eq(Date.new(2026, 10, 1))
    expect(CustomsTariffUpdate.count).to eq(1)
  end
end
