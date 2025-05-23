RSpec.describe GreenLanes::CategoryAssessmentJson do
  describe '.load_from_string' do
    subject(:categorisation) { described_class.load_from_string json_string }

    before do
      create(:geographical_area, :with_reference_group_and_members, :with_description)
    end

    context 'with valid json array' do
      let(:json_string) do
        '[{
          "category": "1",
          "regulation_id": "D0000001",
          "measure_type_id": "400",
          "geographical_area_id": "EU",
          "document_codes": [],
          "additional_codes": [],
          "theme": "1.1 Sanctions"
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
        it { is_expected.to have_attributes document_codes: [] }
        it { is_expected.to have_attributes additional_codes: [] }
        it { is_expected.to have_attributes excluded_geographical_areas: [] }
        it { is_expected.to have_attributes theme: '1.1 Sanctions' }

        it 'returns an instance of GeographicalArea' do
          expect(first_element.geographical_area).to be_instance_of(GeographicalArea)
        end
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

    before do
      create(:geographical_area, :with_reference_group_and_members, :with_description)
    end

    context 'with valid json file' do
      let(:test_file) { file_fixture 'green_lanes/categorisations.json' }

      it { is_expected.to be_an Array }
      it { is_expected.to all be_instance_of described_class }
      it { is_expected.to all be_frozen }
      it { is_expected.to have_attributes length: 10 }

      context 'with attributes' do
        subject(:first_element) { categorisation_file.first }

        it { is_expected.to have_attributes id: a_string_matching(/\A.+\z/) }
        it { is_expected.to have_attributes category: '1' }
        it { is_expected.to have_attributes regulation_id: 'D000001' }
        it { is_expected.to have_attributes measure_type_id: '400' }
        it { is_expected.to have_attributes document_codes: %w[C004 N800] }
        it { is_expected.to have_attributes additional_codes: %w[A5 R2D2] }
        it { is_expected.to have_attributes theme: '1.1 Sanctions' }
        it { is_expected.to have_attributes excluded_geographical_areas: [] }

        it 'returns an instance of GeographicalArea' do
          expect(first_element.geographical_area).to be_instance_of(GeographicalArea)
        end
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

  # rubocop:disable RSpec/AnyInstance
  describe '.load_from_s3' do
    let(:json_string) do
      '[{
          "category": "1",
          "regulation_id": "D0000001",
          "measure_type_id": "400",
          "geographical_area_id": "EU",
          "document_codes": [],
          "additional_codes": [],
          "theme": "1.1 Sanctions"
        }]'
    end

    context 'when the file exists in S3' do
      subject(:s3_categories) { described_class.load_from_s3 }

      before do
        allow_any_instance_of(Aws::S3::Object).to receive_message_chain(:get, :body, :read).and_return(json_string)
      end

      it { is_expected.to be_an Array }
      it { is_expected.to all be_instance_of described_class }
      it { is_expected.to all be_frozen }
      it { is_expected.to have_attributes length: 1 }
    end

    context 'when the specified file key does not exist in S3' do
      before do
        allow_any_instance_of(Aws::S3::Bucket).to receive(:object).and_raise(Aws::S3::Errors::NoSuchKey.new({}, 'File not found'))
      end

      it 'raise InvalidFile error' do
        expect { described_class.load_from_s3 }.to raise_error(GreenLanes::CategoryAssessmentJson::InvalidFile)
      end
    end
  end
  # rubocop:enable RSpec/AnyInstance

  describe '.filter' do
    before { described_class.load_from_file test_file }

    let(:test_file) { file_fixture 'green_lanes/categorisations.json' }

    context 'with matching regulation_id and measure_type_id' do
      subject(:categorisation_filter) do
        described_class.filter regulation_id: 'D000004', measure_type_id: '430'
      end

      it { is_expected.to be_an Array }
      it { is_expected.to have_attributes length: 1 }
      it { expect(categorisation_filter.first).to have_attributes regulation_id: 'D000004', measure_type_id: '430' }
    end

    context 'when regulation_id is blank' do
      subject(:categorisation_filter) do
        described_class.filter regulation_id: '', measure_type_id: '430'
      end

      it { is_expected.to be_an Array }
      it { is_expected.to be_empty }
    end

    context 'when geographical_area is specified' do
      subject(:categorisation_filter) do
        described_class.filter regulation_id: 'D000004', measure_type_id: '430', geographical_area: 'EU'
      end

      it { expect(categorisation_filter.first).to have_attributes regulation_id: 'D000004', measure_type_id: '430' }
    end
  end

  describe '#match?' do
    subject(:categorisation) do
      described_class.new regulation_id: 'D000004', measure_type_id: '430', geographical_area_id:
    end

    let(:geographical_area_id) { 'US' }

    context 'when the attributes match' do
      it do
        expect(categorisation.match?(regulation_id: 'D000004',
                                     measure_type_id: '430',
                                     geographical_area: 'US')).to be true
      end
    end

    context 'when the attributes match and geographical_area is NOT specified' do
      it do
        expect(categorisation.match?(regulation_id: 'D000004', measure_type_id: '430')).to be true
      end
    end

    context 'when the attributes match and geographical_area is empty' do
      it do
        expect(categorisation.match?(regulation_id: 'D000004',
                                     measure_type_id: '430',
                                     geographical_area: '')).to be true
      end
    end

    context 'when the attributes match and geographical_area is ERGA OMNES' do
      let(:geographical_area_id) { GeographicalArea::ERGA_OMNES_ID }

      it 'matches any origin with Erga Omnes' do
        expect(categorisation.match?(regulation_id: 'D000004',
                                     measure_type_id: '430',
                                     geographical_area: 'IT')).to be true
      end
    end

    context 'when regulation_id does NOT match' do
      it do
        expect(categorisation.match?(regulation_id: 'XXX',
                                     measure_type_id: '430',
                                     geographical_area: 'US')).to be false
      end
    end

    context 'when geographical_area does NOT match' do
      it do
        expect(categorisation.match?(regulation_id: 'D000004',
                                     measure_type_id: '430',
                                     geographical_area: 'XXX')).to be false
      end
    end
  end

  describe '#certificates' do
    subject { described_class.new(document_codes:).certificates }

    before { certs }

    let(:document_codes) { %w[Y123 999L] }

    let :certs do
      [
        create(:certificate, certificate_type_code: 'Y', certificate_code: '123'),
        create(:certificate, certificate_type_code: '9', certificate_code: '99L'),
      ]
    end

    it { is_expected.to match_array certs }
  end

  describe '#additional_code_instances' do
    subject { described_class.new(additional_codes:).additional_code_instances }

    before { codes }

    let(:additional_codes) { %w[X987 ABCD] }

    let :codes do
      [
        create(:additional_code, additional_code_type_id: 'X', additional_code: '987'),
        create(:additional_code, additional_code_type_id: 'A', additional_code: 'BCD'),
      ]
    end

    it { is_expected.to match_array codes }
  end

  describe '#exemptions' do
    subject { described_class.new(document_codes:, additional_codes:).exemptions }

    before { exemptions }

    let(:document_codes) { %w[Y123] }
    let(:additional_codes) { %w[X987] }

    let :exemptions do
      [
        create(:certificate, certificate_type_code: 'Y', certificate_code: '123'),
        create(:additional_code, additional_code_type_id: 'X', additional_code: '987'),
      ]
    end

    it { is_expected.to match_array exemptions }
  end
end
