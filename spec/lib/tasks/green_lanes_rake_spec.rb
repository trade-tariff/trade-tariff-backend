# rubocop:disable RSpec/DescribeClass
require 'csv'
require 'fileutils'
require 'tmpdir'

RSpec.describe 'green_lanes rake tasks' do
  let(:task) { Rake::Task['green_lanes:generate_categorisation_data'] }
  let(:tempdir) { Dir.mktmpdir }
  let(:root) { Pathname.new(tempdir) }
  let(:input_path) { root.join('categorisation.csv') }
  let(:output_path) { root.join('data/green_lanes/categories.json') }
  let!(:original_csvfile) { ENV.fetch('CSVFILE', nil) }

  before do
    allow(Rails).to receive(:root).and_return(root)
  end

  after do
    task.reenable
    original_csvfile ? ENV['CSVFILE'] = original_csvfile : ENV.delete('CSVFILE')
    FileUtils.remove_entry(tempdir) if File.exist?(tempdir)
  end

  it 'loads the Rails environment' do
    expect(task.prerequisites).to include('environment')
  end

  it 'rejects a missing input file' do
    ENV['CSVFILE'] = input_path.to_s

    expect { task.invoke }
      .to raise_error(RuntimeError, "Cannot read file '#{input_path}'")
    expect(output_path).not_to exist
  end

  it 'normalizes the CSV and writes pretty JSON to the Green Lanes data directory' do
    root.join('data').mkpath
    CSV.open(input_path, 'w') do |csv|
      csv << ['Primary category', 'Regulation id', 'Measure type ID', 'Geographical area', 'Document codes', 'Additional codes', 'Theme']
      csv << ['1', ' R123 ', ' M456 ', ' XI ', ' C644 N990 ', ' 1234 5678 ', ' Theme name ']
      csv << [' 2 ', ' ', nil, ' ', nil, ' ', nil]
    end
    ENV['CSVFILE'] = input_path.to_s

    task.invoke

    expected = [
      {
        category: '1',
        regulation_id: 'R123',
        measure_type_id: 'M456',
        geographical_area_id: 'XI',
        document_codes: %w[C644 N990],
        additional_codes: %w[1234 5678],
        theme: 'Theme name',
      },
      {
        category: ' 2 ',
        regulation_id: nil,
        measure_type_id: nil,
        geographical_area_id: nil,
        document_codes: [],
        additional_codes: [],
        theme: '',
      },
    ]

    expect(output_path).to exist
    expect(output_path.read).to eq(JSON.pretty_generate(expected))
  end
end
# rubocop:enable RSpec/DescribeClass
