# frozen_string_literal: true

# Simulates the Aurora read replica enforcement for GET/HEAD requests in the
# test environment.
#
# In production, UseReaderForReads routes GET/HEAD requests through
# Sequel::Model.db.with_server(:read_only), which targets the Aurora reader
# endpoint.  Aurora rejects any DML on that connection at the PostgreSQL level.
#
# In test we cannot use a second connection pool — doing so would break
# DatabaseCleaner's :transaction strategy because the reader connection
# cannot see data that is uncommitted on the writer connection.
#
# Instead, this module prepends onto Sequel::Database to:
#   1. Track entry into with_server(:read_only) blocks via a thread-local
#      nesting counter (a counter, not a boolean, so nested calls are safe).
#   2. Raise WriteOnReadOnlyConnectionError before executing any INSERT,
#      UPDATE, DELETE, or TRUNCATE while that counter is positive.
#
# Transaction control statements (BEGIN, COMMIT, ROLLBACK, SAVEPOINT) are
# deliberately not blocked — they are required for DatabaseCleaner to function
# and would never appear inside a real GET handler anyway.
#
# Test failures from this enforcer look like:
#
#   ReadOnlyConnectionEnforcement::WriteOnReadOnlyConnectionError:
#     Write attempted on read-only connection (GET/HEAD request):
#       INSERT INTO "uk"."some_oplog" ...
#
module ReadOnlyConnectionEnforcement
  # Distinct error class so specs can rescue it explicitly and so the cause
  # is immediately obvious from the failure message.
  WriteOnReadOnlyConnectionError = Class.new(Sequel::Error)

  WRITE_RE = /\A\s*(?:INSERT|UPDATE|DELETE|TRUNCATE)\b/i
  NESTING_KEY = :read_only_connection_enforcement_depth

  module DatabaseMethods
    # Increment the nesting counter on entry to any with_server(:read_only)
    # block, decrement on exit.  Handles nested calls correctly.
    def with_server(default_server, read_only_server = default_server, &block)
      tracking = (read_only_server == :read_only)
      Thread.current[NESTING_KEY] = (Thread.current[NESTING_KEY] || 0) + 1 if tracking
      super
    ensure
      Thread.current[NESTING_KEY] -= 1 if tracking && Thread.current[NESTING_KEY]
    end

    # Intercept every SQL statement.  Reject DML when the nesting counter is
    # positive — the enforcer raises before the statement reaches the database,
    # so the SQL text does not need to be valid.
    def execute(sql, *args, &block)
      if (Thread.current[NESTING_KEY] || 0) > 0 && WRITE_RE.match?(sql.to_s)
        raise WriteOnReadOnlyConnectionError,
              "Write attempted on read-only connection (GET/HEAD request):\n  #{sql.to_s.strip}"
      end

      super
    end
  end
end

Sequel::Database.prepend(ReadOnlyConnectionEnforcement::DatabaseMethods)
