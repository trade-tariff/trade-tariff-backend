RSpec.describe MeasureTypeExclusion do
  before do
    allow(described_class).to receive(:exclusions).and_return(test_exclusions)
  end

  let(:test_exclusions) { {} }
  let(:test_csv_file) { file_fixture('measure_type_exclusions.csv') }

  describe '.load_from_file' do
    subject { described_class.load_from_file(test_csv_file).exclusions }

    it { is_expected.to eql(%w[735 1008] => %w[GB JE GG]) }
  end

  describe '.find' do
    subject { described_class.find('735', '1008') }

    before { described_class.load_from_file(test_csv_file) }

    it { is_expected.to eql %w[GB JE GG] }

    context 'with unknown key' do
      subject { described_class.find('738', '1008') }

      it { is_expected.to eql [] }
    end
  end

  describe '.find_geographical_areas' do
    subject { described_class.find_geographical_areas('735', '1008') }

    before { described_class.load_from_file(test_csv_file) }

    context 'with known countries' do
      let!(:gb) { create(:geographical_area, geographical_area_id: 'GB') }
      let!(:je) { create(:geographical_area, geographical_area_id: 'JE') }
      let!(:gg) { create(:geographical_area, geographical_area_id: 'GG') }

      it { is_expected.to eql [gb, gg, je] }
    end

    context 'with unknown areas' do
      let!(:gb) { create(:geographical_area, geographical_area_id: 'GB') }

      it { is_expected.to eql [gb] }
    end

    context 'with known key' do
      subject { described_class.find_geographical_areas('738', '1008') }

      it { is_expected.to eql [] }
    end
  end
end
