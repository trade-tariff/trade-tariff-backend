# frozen_string_literal: true

require 'open3'
require 'spec_helper'

RSpec.describe 'json_schema initializer' do # rubocop:disable RSpec/DescribeClass
  it 'does not prevent the Rails app from booting when json-schema has not already been loaded' do
    output, status = Open3.capture2e(
      { 'RAILS_ENV' => 'development' },
      'bundle', 'exec', 'rails', 'runner', 'puts :booted'
    )

    expect(output).to include('booted')
    expect(status).to be_success
  end
end
