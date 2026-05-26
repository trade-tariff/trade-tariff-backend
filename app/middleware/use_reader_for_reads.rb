# frozen_string_literal: true

# Routes GET and HEAD requests to the Aurora reader instance. All other HTTP
# methods (POST, PUT, PATCH, DELETE) use Sequel's default writer connection.
#
# Sequel's server_block extension (already loaded in application.rb) sets a
# thread-local so every Sequel::Model.db[...] call within the block is
# transparently routed to the :reader server defined in database.yml.
#
# The server is deliberately named :reader instead of :read_only. Sequel treats
# :read_only as a reserved default for all SELECT queries in sharded mode. By not
# defining a :read_only server, Sidekiq and non-GET web requests fall back to the
# writer unless this middleware explicitly selects the reader.
class UseReaderForReads
  READ_METHODS = %w[GET HEAD].freeze

  def initialize(app)
    @app = app
  end

  def call(env)
    if read_request?(env)
      Sequel::Model.db.with_server(:reader) { @app.call(env) }
    else
      @app.call(env)
    end
  end

private

  def read_request?(env)
    READ_METHODS.include?(env['REQUEST_METHOD'])
  end
end
