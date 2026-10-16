RSpec.describe 'replay missed XI deletes' do
  let(:db) { Sequel::Model.db }
  let(:filename) { '20261016120000_replay_missed_xi_deletes' }
  let(:deletions) do
    manifest = JSON.parse(Rails.root.join('db/data_migrations/data', "#{filename}.json").read, symbolize_names: true)
    manifest.flat_map do |group|
      group.fetch(:deletions).map do |deletion|
        deletion.merge(model: group.fetch(:model), attributes: group.fetch(:columns).map(&:to_sym).zip(deletion.fetch(:values)).to_h)
      end
    end
  end
  let(:migration) do
    load Rails.root.join('db/data_migrations', "#{filename}.rb")
    Sequel::Migration.descendants.pop
  end
  let(:measure_deletion) { deletions.find { |deletion| deletion[:model] == 'Measure' } }

  before do
    allow(TradeTariffBackend).to receive(:xi?).and_return(true)
  end

  def nomenclature_deletion
    deletions.find { |deletion| deletion[:model] == 'GoodsNomenclature' }
  end

  def operations_for(deletion)
    model = deletion.fetch(:model).constantize
    model.operation_klass.where(deletion.fetch(:attributes).slice(*Array(model.primary_key)))
  end

  # Insert oplog rows directly to reproduce the old importer's stale projections.
  def seed_operation(deletion, overrides = {})
    model = deletion.fetch(:model).constantize
    model.operation_klass.insert(deletion.fetch(:attributes).merge(
      operation: 'C', operation_date: Date.iso8601(deletion.fetch(:create_date)), filename: nil,
    ).merge(overrides))
  end

  it 'bounds and identifies the source deletes' do
    expect(deletions.length).to eq(1317)
    expect(deletions.tally.size).to eq(1317)
    expect(deletions.map { |row| [row[:model], row[:attributes].slice(*Array(row[:model].constantize.primary_key))] }.uniq.size).to eq(1317)
    expect(deletions.all? { |row| row[:source_file].first(10) <= '2026-05-08' && row[:source_record].positive? }).to be(true)
    # C/D/C source sequences must stay live, even when the last C has the same date.
    expect(deletions.any? { |row| row[:attributes][:measure_sid] == 4_146_245 }).to be(false)
    expect(deletions.any? { |row| row[:attributes][:base_regulation_id] == 'R2511891' }).to be(false)
    expect(deletions.any? { |row| row[:attributes][:base_regulation_id] == 'R2517230' }).to be(false)
    expect(deletions.any? { |row| row[:model] == 'Footnote' }).to be(false)
  end

  it 'repairs the full set and reverses only its additions' do
    deletions.each do |deletion|
      deletion.fetch(:expected_operations).times { seed_operation(deletion) }
    end
    models = deletions.map { |deletion| deletion[:model].constantize }.uniq
    original_rows = models.index_with { |model| model.operation_klass.order(:oid).all.map(&:values) }
    Measure.refresh!(concurrently: false)
    expect(TimeMachine.no_time_machine { Measure.count }).to eq(1221)

    migration.apply(db, :up)

    deletions.each do |deletion|
      history = operations_for(deletion).order(:oid).all
      expect(history.length).to eq(deletion.fetch(:expected_operations) + 1)
      expect(history.last.values.except(:oid, :created_at, :operation, :operation_date, :filename))
        .to eq(history.first.values.except(:oid, :created_at, :operation, :operation_date, :filename))
      expect(history.last.values.slice(:operation, :operation_date, :filename)).to eq(
        operation: 'D', operation_date: Date.iso8601(deletion.fetch(:source_file).first(10)), filename: filename,
      )
    end
    Measure.refresh!(concurrently: false)
    expect(TimeMachine.no_time_machine { Measure.count }).to eq(0)

    migration.apply(db, :up)
    expect(models.sum { |model| model.operation_klass.where(filename: filename).count }).to eq(1317)

    migration.apply(db, :down)
    models.each do |model|
      expect(model.operation_klass.order(:oid).all.map(&:values)).to eq(original_rows.fetch(model))
    end
  end

  %w[C U D].each do |operation|
    it "preserves a later #{operation} operation, even on the same day" do
      seed_operation(measure_deletion)
      seed_operation(measure_deletion, operation: operation)

      migration.apply(db, :up)

      expect(operations_for(measure_deletion).where(filename: filename)).to be_empty
    end
  end

  it 'preserves changed identifiers and dates' do
    deletions.select { |deletion| %w[Measure GoodsNomenclature].include?(deletion[:model]) }.first(3).each do |deletion|
      seed_operation(deletion, goods_nomenclature_item_id: '9999999999')
    end
    seed_operation(nomenclature_deletion, operation_date: Date.new(2026, 5, 13))

    migration.apply(db, :up)

    expect(Measure::Operation.where(filename: filename)).to be_empty
    expect(GoodsNomenclature::Operation.where(filename: filename)).to be_empty
  end

  it 'leaves unrelated deletes and later history on down' do
    seed_operation(measure_deletion)
    migration.apply(db, :up)
    seed_operation(measure_deletion, operation: 'U', operation_date: Date.new(2026, 7, 16))
    seed_operation(measure_deletion, operation: 'D', filename: 'another_repair')
    seed_operation(measure_deletion, measure_sid: 9_999_999, operation: 'D', filename: filename)

    migration.apply(db, :down)

    expect(operations_for(measure_deletion).order(:oid).select_map(:operation)).to eq(%w[C U D])
    expect(Measure::Operation.where(filename: 'another_repair').count).to eq(1)
    expect(Measure::Operation.where(measure_sid: 9_999_999, filename: filename).count).to eq(1)
  end

  [GoodsNomenclatureIndent, GoodsNomenclatureDescription, Measure].each do |child|
    it "preserves nomenclatures with a live #{child}" do
      seed_operation(nomenclature_deletion)
      child.operation_klass.insert(
        Array(child.primary_key).index_with { 9_999_999 }.merge(
          goods_nomenclature_sid: nomenclature_deletion.fetch(:attributes).fetch(:goods_nomenclature_sid),
          operation: 'C', operation_date: Date.new(2026, 5, 1)
        ),
      )

      migration.apply(db, :up)

      expect(operations_for(nomenclature_deletion).where(filename: filename)).to be_empty
    end
  end

  it 'uses the latest child state, not the stale measures view' do
    seed_operation(nomenclature_deletion)
    sid = nomenclature_deletion.fetch(:attributes).fetch(:goods_nomenclature_sid)
    Measure::Operation.insert(measure_sid: 9_999_999, goods_nomenclature_sid: sid, operation: 'C')
    Measure::Operation.insert(measure_sid: 9_999_999, goods_nomenclature_sid: sid + 1, operation: 'U')

    migration.apply(db, :up)

    expect(operations_for(nomenclature_deletion).order(:oid).last.operation).to eq('D')
  end

  it 'stays deleted at the July replay boundary' do
    seed_operation(measure_deletion)
    migration.apply(db, :up)

    operations_for(measure_deletion).where(Sequel[:operation_date] > Date.new(2026, 5, 8)).delete

    expect(operations_for(measure_deletion).order(:oid).last.operation).to eq('D')
  end

  it 'dates cross-file deletes on the deletion file' do
    deletion = deletions.find { |row| row[:attributes][:measure_sid] == 4_182_293 }
    seed_operation(deletion)
    migration.apply(db, :up)
    expect(operations_for(deletion).order(:oid).last.operation_date).to eq(Date.new(2025, 9, 10))

    operations_for(deletion).where(Sequel[:operation_date] > Date.new(2025, 9, 9)).delete

    expect(operations_for(deletion).order(:oid).select_map(:operation)).to eq(%w[C])
  end

  it 'does not change the UK service' do
    allow(TradeTariffBackend).to receive(:xi?).and_return(false)
    seed_operation(measure_deletion)

    migration.apply(db, :up)
    migration.apply(db, :down)

    expect(operations_for(measure_deletion).order(:oid).select_map(:operation)).to eq(%w[C])
  end
end
