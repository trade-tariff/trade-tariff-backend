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

  context 'when importing themes' do
    let(:task) { Rake::Task['green_lanes:import_themes'] }
    let(:source_path) { root.join('data/green_lanes/themes.html') }

    before do
      allow(TradeTariffBackend).to receive(:xi?).and_return(true)
    end

    it 'loads the Rails environment' do
      expect(task.prerequisites).to include('environment')
    end

    it 'rejects execution outside the XI service' do
      allow(TradeTariffBackend).to receive(:xi?).and_return(false)

      expect { task.invoke }
        .to raise_error(RuntimeError, 'Not in XI environment')
    end

    it 'rejects a missing themes file' do
      expect { task.invoke }
        .to raise_error(RuntimeError, "Cannot read file '#{source_path}'")
    end

    it 'rolls back the document when a later theme is malformed' do
      existing = create(
        :green_lanes_theme,
        section: 1,
        subsection: 1,
        theme: 'Original theme',
        description: 'Original description',
        category: 2,
      )
      source_path.dirname.mkpath
      source_path.write <<~HTML
        <div id="anx_IV">
          <p class="oj-ti-grseq-1">Category 1</p>
          <table><tr><td>1.</td><td>Updated theme</td></tr></table>
          <table><tr><td>2.</td><td>New theme</td></tr></table>
          <table><tr><td>3.</td></tr></table>
        </div>
      HTML

      expect { task.invoke }.to raise_error(StandardError)
      expect(existing.refresh.values).to include(
        theme: 'Original theme',
        description: 'Original description',
        category: 2,
      )
      expect(GreenLanes::Theme.count).to eq(1)
    end

    it 'creates and updates themes from the Annex IV document' do
      existing = create(:green_lanes_theme, section: 1, subsection: 1, category: 2)
      long_description = 'A' * 260
      source_path.dirname.mkpath
      source_path.write <<~HTML
        <div id="anx_IV">
          <p class="oj-ti-grseq-1">Category 1</p>
          <table><tr><td>1.</td><td> Updated theme </td></tr></table>
          <table><tr><td>2.</td><td>#{long_description}</td></tr></table>
          <p class="oj-ti-grseq-1">Category 2</p>
          <table><tr><td>1.</td><td>Second category</td></tr></table>
        </div>
      HTML

      task.invoke

      themes = GreenLanes::Theme.order(:section, :subsection).all
      expect(themes.map { |theme| [theme.section, theme.subsection] }).to eq([[1, 1], [1, 2], [2, 1]])
      expect(existing.refresh.values).to include(theme: 'Updated theme', description: 'Updated theme', category: 1)
      expect(themes.second.values).to include(theme: long_description.slice(0, 254), description: long_description, category: 1)
      expect(themes.third.values).to include(theme: 'Second category', description: 'Second category', category: 2)
    end
  end
end
# rubocop:enable RSpec/DescribeClass
