RSpec.describe SwaggerRakeTasks do
  describe '.remove_rswag_getters' do
    subject(:processed_document) { described_class.remove_rswag_getters(document) }

    let(:document) do
      {
        'paths' => {
          '/api/search' => {
            'parameters' => [
              { 'name' => 'Accept', 'getter' => 'accept', 'in' => 'header' },
              { '$ref' => '#/components/parameters/accept_header' },
            ],
          },
        },
        'components' => {
          'parameters' => {
            'accept_header' => { 'name' => 'Accept', 'getter' => 'accept', 'in' => 'header' },
          },
        },
      }
    end

    it 'recursively removes rswag getter metadata' do
      expect(processed_document).to eq(
        'paths' => {
          '/api/search' => {
            'parameters' => [
              { 'name' => 'Accept', 'in' => 'header' },
              { '$ref' => '#/components/parameters/accept_header' },
            ],
          },
        },
        'components' => {
          'parameters' => {
            'accept_header' => { 'name' => 'Accept', 'in' => 'header' },
          },
        },
      )
    end
  end

  describe '.public_paths' do
    subject(:public_paths) { described_class.public_paths(paths) }

    let(:internal_path) { described_class::INTERNAL_PATHS.fetch(0) }
    let(:paths) do
      {
        '/api/sections' => { 'get' => { 'summary' => 'Sections' } },
        internal_path => { 'get' => { 'summary' => 'Internal' } },
        '/api/commodities/{id}' => { 'get' => { 'summary' => 'Commodities' } },
      }
    end

    it 'drops internal paths and sorts keys' do
      expect(public_paths.keys).to eq(['/api/commodities/{id}', '/api/sections'])
      expect(public_paths.values).to eq(
        [
          { 'get' => { 'summary' => 'Commodities' } },
          { 'get' => { 'summary' => 'Sections' } },
        ],
      )
    end
  end

  describe '.check_coverage' do
    context 'when all controllers have specs' do
      it 'prints a coverage message' do
        expect { described_class.check_coverage }.to output(
          "All public V2 controllers have swagger specs.\n",
        ).to_stdout
      end
    end

    context 'when a controller spec is missing' do
      let(:missing_controller) { 'missing_swagger_coverage_controller.rb' }
      let(:missing_report) do
        <<~MESSAGE
          The following V2 controllers have no swagger spec:
            app/controllers/api/v2/#{missing_controller}

          Add a spec under spec/swagger/api/v2/ or add the controller
          to the excluded/combined lists in lib/tasks/swagger.rake.
        MESSAGE
      end

      before do
        allow(described_class).to receive(:controllers).and_return([missing_controller])
      end

      it 'reports the controller and exits' do
        expect { described_class.check_coverage }
          .to output(missing_report).to_stderr
          .and raise_error(SystemExit) { |error| expect(error.status).to eq(1) }
      end
    end
  end

  describe 'swagger:generate' do
    subject(:task) { Rake::Task['swagger:generate'] }

    before { task.reenable }

    it 'omits the environment prerequisite' do
      expect(task.prerequisites).not_to include('environment')
    end

    it 'delegates to SwaggerRakeTasks.generate' do
      allow(described_class).to receive(:generate)

      task.invoke

      expect(described_class).to have_received(:generate).with(no_args)
    end
  end

  describe 'swagger:check_coverage' do
    subject(:task) { Rake::Task['swagger:check_coverage'] }

    before { task.reenable }

    it 'omits the environment prerequisite' do
      expect(task.prerequisites).not_to include('environment')
    end

    it 'delegates to SwaggerRakeTasks.check_coverage' do
      allow(described_class).to receive(:check_coverage)

      task.invoke

      expect(described_class).to have_received(:check_coverage).with(no_args)
    end
  end
end
