require 'sequel/extensions/migration'

RSpec.describe 'Replay missed XI nomenclature deletes' do
  subject(:migrate) { migration.apply(Sequel::Model.db, :up) }

  migration_filename = '20261015143000_replay_missed_xi_nomenclature_deletes'

  let(:migration) do
    load Rails.root.join("db/data_migrations/#{migration_filename}.rb")
    Sequel::Migration.descendants.pop
  end
  let(:operations) { GoodsNomenclature::Operation }
  let(:repairs) { operations.where(filename: migration_filename) }
  let(:source_records) do
    [
      [110_252, '2106108070', '10', '2025-08-29', '2025-06-23'],
      [110_518, '7212600020', '10', '2026-01-17', '2026-01-11'],
      [110_523, '7212600020', '80', '2026-01-17', '2026-01-11'],
      [110_543, '2904990075', '80', '2026-07-01', '2026-02-02'],
      [110_673, '8708509192', '80', '2026-02-27', '2026-02-11'],
      [110_720, '7307191035', '20', '2023-01-20', '2026-03-29'],
      [110_721, '7307191049', '80', '2023-01-20', '2026-03-29'],
      [110_764, '9705100042', '20', '2026-06-11', '2026-04-24'],
      [110_772, '7212506998', '80', '2026-01-01', '2026-04-27'],
    ]
  end
  let!(:ghosts) do
    source_records.map do |sid, code, suffix, validity_start, source_date|
      create(:goods_nomenclature, :without_indent,
             goods_nomenclature_sid: sid,
             goods_nomenclature_item_id: code,
             producline_suffix: suffix,
             validity_start_date: validity_start,
             operation_date: source_date)
    end
  end

  before do
    allow(TradeTariffBackend).to receive(:xi?).and_return(true)
    travel_to Time.zone.local(2026, 10, 15)
  end

  it 'repairs the tree without reviving indents' do
    chapter = create(:chapter, goods_nomenclature_item_id: '7200000000')
    heading = create(:heading, goods_nomenclature_item_id: '7212000000', parent: chapter)
    clad = create(:goods_nomenclature, goods_nomenclature_item_id: '7212600000', parent: heading)
    grouping = create(:goods_nomenclature, :grouping, goods_nomenclature_item_id: '7212600012', parent: clad)
    replacement = create(:goods_nomenclature, :with_description,
                         goods_nomenclature_sid: 110_526,
                         goods_nomenclature_item_id: '7212600020',
                         description: 'Other', parent: grouping)
    checker = TreeIntegrityCheckingService.new
    expect(checker.check!).to be false
    expect(checker.failures).to eq Set.new(source_records.map(&:first))

    migrate
    MaterializeViewHelper.refresh_materialized_view

    expect(TreeIntegrityCheckingService.new.check!).to be true
    expect(GoodsNomenclature.where(goods_nomenclature_sid: source_records.map(&:first))).to be_empty
    expect(replacement.refresh.number_indents).to eq 3
    expect(replacement.description).to eq 'Other'
    expect(replacement.parent.goods_nomenclature_sid).to eq grouping.goods_nomenclature_sid
  end

  it 'preserves history and marks the repairs' do
    originals = operations.order(:oid).map(&:values)

    migrate

    expect(operations.order(:oid).limit(originals.length).map(&:values)).to eq originals
    expect(repairs.order(:goods_nomenclature_sid).select_map(%i[goods_nomenclature_sid operation operation_date]))
      .to eq(source_records.map { |sid, *| [sid, 'D', Date.new(2026, 10, 15)] })
  end

  it 'is idempotent before a view refresh' do
    migrate

    expect { migration.apply(Sequel::Model.db, :up) }.not_to change(operations, :count)
  end

  it 'skips records already deleted upstream' do
    ghosts.first.destroy

    migrate

    expect(repairs.select_map(:goods_nomenclature_sid)).not_to include(110_252)
  end

  it 'preserves later upstream operations' do
    ghosts.first.update(operation_date: Date.new(2026, 10, 14))

    migrate

    expect(repairs.select_map(:goods_nomenclature_sid)).not_to include(110_252)
  end

  it 'preserves a restored indent' do
    create(:goods_nomenclature_indent, goods_nomenclature: ghosts.first, number_indents: 3)

    migrate

    expect(repairs.select_map(:goods_nomenclature_sid)).not_to include(110_252)
  end

  it 'preserves a restored description' do
    create(:goods_nomenclature_description, goods_nomenclature_sid: 110_252)

    migrate

    expect(repairs.select_map(:goods_nomenclature_sid)).not_to include(110_252)
  end

  it 'preserves a record with measures' do
    create(:measure, goods_nomenclature_sid: 110_252)

    migrate

    expect(repairs.select_map(:goods_nomenclature_sid)).not_to include(110_252)
  end

  describe 'rollback' do
    it 'removes only the migration operations' do
      originals = operations.order(:oid).map(&:values)
      migrate
      later = operations.where(goods_nomenclature_sid: 110_252).order(Sequel.desc(:oid)).first.values.except(:oid)
      later[:filename] = 'later-upstream.xml'
      later[:operation_date] = Date.new(2026, 10, 16)
      later_oid = operations.insert(later)

      migration.apply(Sequel::Model.db, :down)
      MaterializeViewHelper.refresh_materialized_view

      expect(repairs).to be_empty
      expect(operations.order(:oid).map(&:values)).to eq originals + [operations[oid: later_oid].values]
      expect(GoodsNomenclature.where(goods_nomenclature_sid: 110_252)).to be_empty
      expect(GoodsNomenclature.where(goods_nomenclature_sid: source_records.drop(1).map(&:first)).count).to eq 8
    end
  end

  context 'with the UK service' do
    before { allow(TradeTariffBackend).to receive(:xi?).and_return(false) }

    it 'leaves operations unchanged both ways' do
      expect {
        migrate
        migration.apply(Sequel::Model.db, :down)
      }.not_to change(operations, :count)
    end
  end
end
