RSpec.describe GreenLanes::Categorisation do
  describe '.load_from_string' do
    subject(:categorisation) { described_class.load_from_string json_string }

    context 'with valid json array' do
      let(:json_string) do
        '[{
          "category": "1",
          "regulation_id": "D0000001",
          "measure_type_id": "400",
          "geographical_area": "1000",
          "document_codes": [],
          "additional_codes": []
        }]'
      end

      it { is_expected.to be_an Array }
      it { is_expected.to all be_instance_of described_class }
      it { is_expected.to have_attributes length: 1 }

      context 'with attributes' do
        subject(:first_element) { categorisation.first }

        it { is_expected.to have_attributes id: a_string_matching(/\A.+\z/) }
        it { is_expected.to have_attributes category: '1' }
        it { is_expected.to have_attributes regulation_id: 'D0000001' }
        it { is_expected.to have_attributes measure_type_id: '400' }
        it { is_expected.to have_attributes geographical_area: '1000' }
        it { is_expected.to have_attributes document_codes: [] }
        it { is_expected.to have_attributes additional_codes: [] }
      end
    end

    context 'with valid json array with multiple elements' do
      let(:json_string) do
        '[
          {
            "category": "2"
          },
          {
            "category": "3"
          },
          {
            "category": "1"
          }
        ]'
      end

      it { is_expected.to be_an Array }
      it { is_expected.to all be_instance_of described_class }
      it { is_expected.to have_attributes length: 3 }
    end
  end

  describe '.load_from_file' do
    subject(:categorisation_file) { described_class.load_from_file test_file }

    context 'with valid json file' do
      let(:test_file) { file_fixture 'green_lanes/categorisations.json' }

      it { is_expected.to be_an Array }
      it { is_expected.to all be_instance_of described_class }
      it { is_expected.to have_attributes length: 10 }

      context 'with attributes' do
        subject(:first_element) { categorisation_file.first }

        it { is_expected.to have_attributes id: a_string_matching(/\A.+\z/) }
        it { is_expected.to have_attributes category: '1' }
        it { is_expected.to have_attributes regulation_id: 'D000001' }
        it { is_expected.to have_attributes measure_type_id: '400' }
        it { is_expected.to have_attributes geographical_area: '1000' }
        it { is_expected.to have_attributes document_codes: %w[C004 N800] }
        it { is_expected.to have_attributes additional_codes: %w[A5 R2D2] }
      end
    end

    context 'with missing file' do
      let(:test_file) do
        Rails.root.join(file_fixture_path).join 'green_lanes/random.json'
      end

      it { expect { categorisation_file }.to raise_exception described_class::InvalidFile }
    end

    context 'with non-JSON file' do
      let(:test_file) { file_fixture 'green_lanes/invalid.csv' }

      it { expect { categorisation_file }.to raise_exception described_class::InvalidFile }
    end
  end

  describe '.all' do
    before { described_class.load_from_file test_file }

    let(:test_file) { file_fixture 'green_lanes/categorisations.json' }

    context 'when all read' do
      subject(:categorisation_all) { described_class.all }

      it { is_expected.to be_an Array }
      it { is_expected.to all be_instance_of described_class }
      it { is_expected.to have_attributes length: 10 }
    end
  end
end
