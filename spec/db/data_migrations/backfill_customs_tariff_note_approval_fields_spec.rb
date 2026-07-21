require 'data_migrator'

RSpec.describe 'Backfill customs tariff note approval fields' do
  subject(:run_migration) do
    Sequel::TimestampMigrator.run_single(
      Sequel::Model.db,
      Rails.root.join('db/data_migrations/20260506130000_backfill_customs_tariff_note_approval_fields.rb').to_s,
      table: DataMigrator::DATA_MIGRATIONS_TABLE,
    )
  end

  let(:validity_start_date) { Date.new(2026, 5, 1) }
  let(:customs_tariff_update) { create(:customs_tariff_update, validity_start_date:) }

  it 'backfills only missing validity start dates against the current schema' do
    section_note = create(:customs_tariff_section_note, customs_tariff_update:, validity_start_date: nil)
    chapter_note = create(:customs_tariff_chapter_note, customs_tariff_update:, validity_start_date: nil)
    general_rule = create(:customs_tariff_general_rule, customs_tariff_update:, validity_start_date: nil)
    populated_note = create(:customs_tariff_section_note, customs_tariff_update:, validity_start_date: Date.new(2026, 4, 1))

    run_migration

    expect([section_note, chapter_note, general_rule, populated_note].map { _1.reload.validity_start_date })
      .to eq([validity_start_date, validity_start_date, validity_start_date, Date.new(2026, 4, 1)])
  end
end
