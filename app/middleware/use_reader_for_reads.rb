# frozen_string_literal: true

# Routes GET and HEAD requests to the Aurora reader instance.  All other HTTP
# methods (POST, PUT, PATCH, DELETE) use the default (writer) connection pool.
#
# Sequel's server_block extension (already loaded in application.rb) sets a
# thread-local so every Sequel::Model.db[...] call within the block is
# transparently routed to the :read_only server defined in database.yml.
#
# Sidekiq workers do not go through Rack middleware and therefore continue
# using the writer, which is correct — they often read data immediately after
# writing it.
class UseReaderForReads
  READ_METHODS = %w[GET HEAD].freeze

  def initialize(app)
    @app = app
  end

  def call(env)
    if READ_METHODS.include?(env['REQUEST_METHOD'])
      Sequel::Model.db.with_server(:read_only) { @app.call(env) }
    else
      @app.call(env)
    end
  end
end
