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

  context 'when importing category assessments' do
    let(:task) { Rake::Task['green_lanes:import_category_assessments'] }
    let(:records) { [] }

    before do
      allow(TradeTariffBackend).to receive(:xi?).and_return(true)
      allow(GreenLanes::CategoryAssessmentJson).to receive(:all).and_return(records)
    end

    it 'loads the Rails environment' do
      expect(task.prerequisites).to include('environment')
    end

    it 'rejects execution outside the XI service' do
      allow(TradeTariffBackend).to receive(:xi?).and_return(false)

      expect { task.invoke }
        .to raise_error(RuntimeError, 'Only supported on XI service')
    end

    it 'skips category 3 and records without a theme' do
      records << category_assessment_json(category: 3, theme: '3.1.Category 3')
      records << category_assessment_json(category: 1, theme: nil)

      expect { task.invoke }
        .to output(/MISSING THEME, SKIPPING:/).to_stdout
      expect(GreenLanes::CategoryAssessment.count).to be_zero
    end

    it 'creates assessments using existing and new themes and resolves regulation roles' do
      existing_theme = create(:green_lanes_theme, section: 1, subsection: 2, category: 1)
      modification = create(:modification_regulation, modification_regulation_id: 'R1234567')
      base = create(:base_regulation, base_regulation_id: 'R2345678', base_regulation_role: 7)
      records << category_assessment_json(
        category: 1,
        measure_type_id: '551',
        regulation_id: modification.modification_regulation_id,
        theme: '1.2.Existing theme',
      )
      records << category_assessment_json(
        category: 2,
        measure_type_id: '552',
        regulation_id: 'R7654321',
        theme: '2.4.Created theme',
      )
      records << category_assessment_json(
        category: 1,
        measure_type_id: '553',
        regulation_id: base.base_regulation_id,
        theme: '1.2.Existing theme',
      )
      records << records.first.dup

      task.invoke

      assessments = GreenLanes::CategoryAssessment.order(:measure_type_id).all
      expect(assessments.map { |assessment| [assessment.measure_type_id, assessment.regulation_role] })
        .to eq([['551', modification.modification_regulation_role], ['552', 1], ['553', base.base_regulation_role]])
      expect(assessments.first.theme).to eq(existing_theme)
      expect(assessments.second.theme.values)
        .to include(section: 2, subsection: 4, category: 2, theme: 'Created theme', description: 'Created theme')
    end

    it 'leaves matching assessments unchanged' do
      theme = create(:green_lanes_theme, section: 1, subsection: 2, category: 1)
      assessment = create(:category_assessment, theme:)
      records << category_assessment_json(
        category: 1,
        measure_type_id: assessment.measure_type_id,
        regulation_id: assessment.regulation_id,
        theme: '1.2.Existing theme',
      )

      expect { task.invoke }.not_to(change { assessment.refresh.values })
      expect(GreenLanes::CategoryAssessment.count).to eq(1)
    end

    it 'rolls back the import when an existing assessment has a different theme' do
      original_theme = create(:green_lanes_theme, section: 1, subsection: 1, category: 1)
      conflicting_theme = create(:green_lanes_theme, section: 1, subsection: 2, category: 1)
      assessment = create(:category_assessment, theme: original_theme)
      records << category_assessment_json(category: 2, measure_type_id: '552', regulation_id: 'R7654321', theme: '2.4.New theme')
      records << category_assessment_json(
        category: 1,
        measure_type_id: assessment.measure_type_id,
        regulation_id: assessment.regulation_id,
        theme: "1.#{conflicting_theme.subsection}.Conflicting theme",
      )

      expect { task.invoke }.to raise_error(RuntimeError, 'Inconsistent theme')
      expect(GreenLanes::CategoryAssessment.all).to contain_exactly(assessment)
      expect(GreenLanes::Theme.order(:section, :subsection).all).to eq([original_theme, conflicting_theme])
    end
  end

  def category_assessment_json(overrides = {})
    GreenLanes::CategoryAssessmentJson.new({
      category: 1,
      measure_type_id: '550',
      regulation_id: 'R0000001',
      theme: '1.1.Theme',
    }.merge(overrides))
  end
end
# rubocop:enable RSpec/DescribeClass
