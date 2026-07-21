RSpec.describe 'Sidekiq Rake tasks' do
  describe 'sidekiq:status' do
    subject(:task) { Rake::Task['sidekiq:status'] }

    let(:status_class) { double }
    let(:status) do
      double(
        complete?: false,
        created_at: '2012-09-04 21:15:05 -0700',
        data: { 'total' => 97 },
        failure_info: ['failed job'],
        failures: 5,
        pending: 17,
        total: 97,
      )
    end

    before do
      stub_const('Sidekiq::Batch::Status', status_class)
      allow(status_class).to receive(:new).with('batch-id').and_return(status)
    end

    after { task.reenable }

    it 'prints every batch status field' do
      expect { task.invoke('batch-id') }.to output(<<~OUTPUT).to_stdout
        batch:        batch-id
        total:        97
        failures:     5
        pending:      17
        created_at:   2012-09-04 21:15:05 -0700
        complete?:    false
        failure_info: ["failed job"]
        data:         {"total" => 97}
      OUTPUT
    end
  end
end
