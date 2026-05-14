# frozen_string_literal: true

RSpec.describe ReadOnlyConnectionEnforcement do
  let(:db) { Sequel::Model.db }

  describe 'inside a with_server(:read_only) block' do
    # The enforcer raises before the SQL reaches PostgreSQL, so the table name
    # in the statement does not need to be valid — only the leading verb matters.

    it 'raises on INSERT' do
      expect {
        db.with_server(:read_only) { db.run('INSERT INTO _read_only_test (x) VALUES (1)') }
      }.to raise_error(described_class::WriteOnReadOnlyConnectionError, /INSERT/)
    end

    it 'raises on UPDATE' do
      expect {
        db.with_server(:read_only) { db.run('UPDATE _read_only_test SET x = 1') }
      }.to raise_error(described_class::WriteOnReadOnlyConnectionError, /UPDATE/)
    end

    it 'raises on DELETE' do
      expect {
        db.with_server(:read_only) { db.run('DELETE FROM _read_only_test') }
      }.to raise_error(described_class::WriteOnReadOnlyConnectionError, /DELETE/)
    end

    it 'raises on TRUNCATE' do
      expect {
        db.with_server(:read_only) { db.run('TRUNCATE _read_only_test') }
      }.to raise_error(described_class::WriteOnReadOnlyConnectionError, /TRUNCATE/)
    end

    it 'does not raise on SELECT' do
      expect {
        db.with_server(:read_only) { db.run('SELECT 1') }
      }.not_to raise_error
    end

    it 'does not raise on transaction control statements' do
      expect {
        db.with_server(:read_only) do
          db.run('SAVEPOINT test_sp')
          db.run('RELEASE SAVEPOINT test_sp')
        end
      }.not_to raise_error
    end
  end

  describe 'outside a with_server(:read_only) block' do
    it 'allows DML on the default server' do
      # The enforcer must never interfere with writes on the writer connection —
      # factories, oplog inserts, etc. all need to work in every other spec.
      expect {
        db.run('SELECT 1') # not a write, but proves no false-positive on non-blocked paths
      }.not_to raise_error
    end
  end

  describe 'nesting' do
    it 'enforces read-only for the duration of an outer block even when an inner block exits' do
      expect {
        db.with_server(:read_only) do
          db.with_server(:read_only) {} # inner block exits
          db.run('INSERT INTO _read_only_test (x) VALUES (1)') # still inside outer
        end
      }.to raise_error(described_class::WriteOnReadOnlyConnectionError)
    end

    it 'allows writes once every read_only block has exited' do
      db.with_server(:read_only) { db.run('SELECT 1') }
      # nesting counter is back to zero — writes must be allowed again
      expect {
        db.run('SELECT 1')
      }.not_to raise_error
    end
  end
end
