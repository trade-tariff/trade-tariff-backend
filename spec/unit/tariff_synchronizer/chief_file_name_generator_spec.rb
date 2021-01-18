require 'rails_helper'
require 'tariff_synchronizer/chief_file_name_generator'

describe TariffSynchronizer::ChiefFileNameGenerator do
  let(:example_date) { Date.new(2010, 1, 1) }
  let(:chief_file_name) { TariffSynchronizer::ChiefFileNameGenerator.new(example_date) }

  describe '#name' do
    it 'returns the expected chief file name for a specific date' do
      expect(chief_file_name.name).to eq('2010-01-01_KBT009(10001).txt')
    end
  end

  describe '#url' do
    it 'returns the expected url to have the chief file for a specific date' do
      expect(chief_file_name.url).to eq('http://example.com/taric/KBT009(10001).txt')
    end
  end
end
