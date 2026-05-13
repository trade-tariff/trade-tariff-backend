# frozen_string_literal: true

RSpec.describe CdsImporter::StagingManager do
  subject(:manager) { described_class.new }

  # A real lightweight oplog table to test against in the DB.
  # MonetaryUnit::Operation is tiny (a handful of rows) and safe to write to.
  let(:real_operation_klass) { MonetaryUnit::Operation }

  describe '#dataset_for' do
    after { manager.cleanup }

    it 'returns a Sequel dataset' do
      expect(manager.dataset_for(real_operation_klass)).to be_a(Sequel::Dataset)
    end

    it 'creates an UNLOGGED staging table on first call' do
      dataset = manager.dataset_for(real_operation_klass)
      table_name = dataset.first_source

      result = Sequel::Model.db.fetch(
        'SELECT relpersistence FROM pg_class WHERE relname = ?',
        table_name.to_s,
      ).first

      expect(result).not_to be_nil
      expect(result[:relpersistence]).to eq('u') # 'u' = UNLOGGED in pg_class
    end

    it 'returns the same dataset on repeated calls for the same operation class' do
      first  = manager.dataset_for(real_operation_klass)
      second = manager.dataset_for(real_operation_klass)

      expect(first.first_source).to eq(second.first_source)
    end

    it 'creates distinct staging tables for different operation classes' do
      ds1 = manager.dataset_for(MonetaryUnit::Operation)
      ds2 = manager.dataset_for(MeasureAction::Operation)

      expect(ds1.first_source).not_to eq(ds2.first_source)
    end

    it 'uses a short fixed-length name that fits within PostgreSQL 63-char limit' do
      dataset = manager.dataset_for(real_operation_klass)
      expect(dataset.first_source.to_s.length).to be <= 63
    end
  end

  describe '#promote!' do
    after { manager.cleanup }

    it 'copies staged rows into the real oplog table inside one transaction' do
      staging_ds = manager.dataset_for(real_operation_klass)

      row = {
        monetary_unit_code: 'TST',
        operation: 'C',
        operation_date: Time.zone.today,
        filename: 'test_file.gzip',
      }
      staging_ds.insert(row)

      expect { manager.promote! }
        .to change {
          real_operation_klass.where(monetary_unit_code: 'TST', filename: 'test_file.gzip').count
        }.by(1)
    ensure
      real_operation_klass.where(monetary_unit_code: 'TST', filename: 'test_file.gzip').delete
    end

    it 'leaves the real table unchanged when staging is empty' do
      manager.dataset_for(real_operation_klass) # create staging, insert nothing

      expect { manager.promote! }
        .not_to(change(real_operation_klass, :count))
    end
  end

  describe '#cleanup' do
    it 'drops all staging tables' do
      dataset = manager.dataset_for(real_operation_klass)
      staging_name = dataset.first_source.to_s

      manager.cleanup

      result = Sequel::Model.db.fetch(
        'SELECT 1 FROM pg_class WHERE relname = ?',
        staging_name,
      ).first

      expect(result).to be_nil
    end

    it 'is idempotent — calling twice does not raise' do
      manager.dataset_for(real_operation_klass)
      manager.cleanup

      expect { manager.cleanup }.not_to raise_error
    end
  end
end
