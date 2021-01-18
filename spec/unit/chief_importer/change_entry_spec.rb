require 'rails_helper'

require 'chief_importer'
require 'chief_importer/change_entry'

# Define a test strategy
class ChiefImporter
  module Strategies
    class TestStrategy < BaseStrategy
    end
  end
end

describe ChiefImporter::ChangeEntry do
  let(:valid_table_name)     { 'TestStrategy' }
  let(:invalid_table_name)   { 'errr' }
  let(:valid_args)           { [valid_table_name] }
  let(:invalid_args)         { [invalid_table_name] }

  describe 'initialization' do
    before do
      # make TestStrategy a valid one
      ChiefImporter.relevant_tables.push('TestStrategy')
    end

    after do
      ChiefImporter.relevant_tables.delete('TestStrategy')
    end

    it 'assigns table name' do
      ce = ChiefImporter::ChangeEntry.new(valid_args)
      expect(ce.table).to eq valid_table_name
    end

    it 'assigns proper available strategy' do
      ce = ChiefImporter::ChangeEntry.new(invalid_args)
      expect(ce.table).to eq invalid_table_name
      expect(ce.strategy).to be_blank

      ce = ChiefImporter::ChangeEntry.new(valid_args)
      expect(ce.table).to eq valid_table_name
      expect(ce.strategy).not_to be_blank
      expect(ce.strategy).to be_kind_of ChiefImporter::Strategies::TestStrategy
    end
  end

  describe '#relevant?' do
    it 'returns false if table is not relevant' do
      expect(
        ChiefImporter::ChangeEntry.new(invalid_args).relevant?,
      ).to be_falsy
    end

    it 'returns true if table is relevant' do
      ChiefImporter.relevant_tables += valid_args

      expect(
        ChiefImporter::ChangeEntry.new(valid_args).relevant?,
      ).to be_truthy

      ChiefImporter.relevant_tables.delete('TestStrategy')
    end
  end
end
