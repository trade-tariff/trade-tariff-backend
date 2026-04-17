# rubocop:disable RSpec/DescribeClass
RSpec.describe 'paper_trail:reset_initial_versions' do
  subject(:run_task) { suppress_output { Rake::Task['paper_trail:reset_initial_versions'].invoke } }

  let(:service) { instance_spy(PaperTrail::ResetInitialVersions, call: true) }

  before do
    Rake::Task['paper_trail:reset_initial_versions'].reenable
    Rake::Task['class_eager_load'].reenable
  end

  after do
    Rake::Task['paper_trail:reset_initial_versions'].reenable
    Rake::Task['class_eager_load'].reenable
    ENV.delete('CONFIRM')
  end

  it 'aborts unless CONFIRM=true' do
    expect { Rake::Task['paper_trail:reset_initial_versions'].invoke }.to raise_error(SystemExit)
  end

  it 'eager loads classes and runs the reset service when confirmed' do
    allow(Rails.application).to receive(:eager_load!).and_return(true)
    allow(PaperTrail::ResetInitialVersions).to receive(:new).and_return(service)
    ENV['CONFIRM'] = 'true'

    run_task

    expect(Rails.application).to have_received(:eager_load!)
    expect(PaperTrail::ResetInitialVersions).to have_received(:new)
    expect(service).to have_received(:call)
  end
end
# rubocop:enable RSpec/DescribeClass
