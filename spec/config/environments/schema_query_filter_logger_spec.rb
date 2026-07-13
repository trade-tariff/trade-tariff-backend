require 'rails_helper'
require_relative '../../../config/environments/development_environment_config'

RSpec.describe SchemaQueryFilterLogger do
  subject(:logger) { described_class.new(inner) }

  let(:inner) { instance_double(Logger, debug: true) }

  it 'suppresses schema-introspection debug noise' do
    logger.debug('SELECT * FROM pg_attribute')
    logger.debug("SELECT current_setting('search_path')")

    expect(inner).not_to have_received(:debug)
  end

  it 'forwards non-schema debug messages' do
    logger.debug('SELECT * FROM measures')

    expect(inner).to have_received(:debug).with('SELECT * FROM measures')
  end
end
