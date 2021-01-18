require 'rails_helper'

RSpec.describe GeographicalAreasImportService do
  subject(:importer) { described_class.new }

  let(:hjid_mappings_file) { Rails.root.join('spec', 'fixtures', 'files', 'hjid_to_sid_map.csv').to_s }
  
  let!(:area) {
    create(:geographical_area, geographical_area_sid: 374)
  }

  before do
    create(:geographical_area)
  end

  describe '#import_hjids' do
    it 'raises error if invalid filename' do
      expect { importer.import_hjids('foo') }.to raise_exception
    end

    it 'does not raise error with valid filename' do
      expect { importer.import_hjids(hjid_mappings_file) }.not_to raise_exception
    end

    it 'updates matching geographical areas' do
      importer.import_hjids(hjid_mappings_file)
      expect(area.reload).to have_attributes(hjid: 23500)
    end
  end

  describe '#import_hjids_stats' do
    before { importer.import_hjids(hjid_mappings_file) }

    it 'reports statistics on completion' do
      expect(importer.import_hjids_stats).to eq(
        geographical_areas_total: 2,
        geographical_areas_with_hjid_total: 1,
        errors: 1
      )
    end
  end
end
