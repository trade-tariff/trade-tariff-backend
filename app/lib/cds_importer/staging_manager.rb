# frozen_string_literal: true

class CdsImporter
  # Coordinates writing CDS import data to UNLOGGED staging tables, then
  # promoting the staged rows into the real oplog tables in a single atomic
  # transaction.
  #
  # Why UNLOGGED?  PostgreSQL UNLOGGED tables bypass the write-ahead log
  # (WAL).  A full CDS daily extract can touch tens of thousands of rows
  # across 50+ oplog tables.  Writing all of that inside one WAL-logged
  # transaction means PostgreSQL must hold every dirty page in shared_buffers
  # (or spill to temp files) until COMMIT — the source of the nightly memory
  # spike.  Writing to UNLOGGED tables generates no WAL at all, so there is
  # no large transaction and no buffer pressure.
  #
  # Atomicity is preserved at the application layer:
  #   1. All rows are written to staging (no transaction needed — UNLOGGED).
  #   2. On success, promote! copies everything into the real oplog tables
  #      inside one short Sequel transaction.  That transaction is tiny in
  #      wall-clock terms because the data is already on disk.
  #   3. On any error, cleanup drops the staging tables before they are ever
  #      promoted, leaving the real oplog tables untouched.
  #
  # Crash safety: if the database crashes during the staging phase, the
  # UNLOGGED tables are lost (PostgreSQL truncates them on recovery), so no
  # partial data lands in the real oplog.  The sync simply re-runs from the
  # source file on S3.
  class StagingManager
    def initialize
      # Short unique ID scoped to this import run.  Used to build staging
      # table names that are guaranteed not to collide with other runs.
      @import_id = SecureRandom.hex(4) # 8 hex chars
      @counter   = 0
      # Maps real oplog table name (Symbol) → staging table name (Symbol)
      @staged_tables = {}
    end

    # Returns a Sequel dataset pointing at the UNLOGGED staging table for the
    # given oplog operation class.  The staging table is created on first access.
    def dataset_for(operation_klass)
      real_table = operation_klass.table_name

      staging_table = @staged_tables[real_table] ||= begin
        name = next_staging_name
        create_staging_table(real_table, name)
        name
      end

      Sequel::Model.db[staging_table]
    end

    # Copies all staged rows into the real oplog tables inside one atomic
    # transaction.  The individual INSERT … SELECT statements are fast because
    # the data is already on disk in the UNLOGGED tables.
    def promote!
      Sequel::Model.db.transaction do
        @staged_tables.each do |real_table, staging_table|
          # Exclude oid: the real table's sequence assigns it on insert.
          columns = Sequel::Model.db[staging_table].columns.reject { |c| c == :oid }
          next if columns.empty?

          Sequel::Model.db[real_table].insert(
            columns,
            Sequel::Model.db[staging_table].select(*columns),
          )
        end
      end
    end

    # Drops all staging tables.  Safe to call even if some tables were never
    # created (uses IF EXISTS) and idempotent across multiple calls.
    def cleanup
      @staged_tables.each_value do |staging_table|
        Sequel::Model.db.run("DROP TABLE IF EXISTS #{staging_table}")
      rescue StandardError => e
        Rails.logger.warn "CdsImporter::StagingManager: failed to drop #{staging_table}: #{e.message}"
      end
      @staged_tables.clear
    end

    private

    # Staging table names are short fixed-length identifiers so they are
    # always under PostgreSQL's 63-character limit, regardless of how long the
    # source oplog table name is.
    #
    # Format: stg_<8-char import id>_<2-digit counter>
    # Example: stg_a1b2c3d4_01
    def next_staging_name
      @counter += 1
      :"stg_#{@import_id}_#{sprintf('%02d', @counter)}"
    end

    # Creates an UNLOGGED table with the same column structure as the real
    # oplog table but without indexes, constraints, or sequences.
    # CREATE TABLE … AS SELECT … WHERE false gives us column names and types
    # without NOT NULL constraints — exactly what we want for a staging area.
    def create_staging_table(real_table, staging_name)
      Sequel::Model.db.run(<<~SQL)
        CREATE UNLOGGED TABLE #{staging_name}
          AS SELECT * FROM #{real_table} WHERE false
      SQL
    end
  end
end
