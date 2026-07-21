# frozen_string_literal: true

RSpec.describe 'database replication Terraform' do
  let(:backend_job_tf) { Rails.root.join('terraform/backend_job.tf').read }

  it 'execs the replication script from the EventBridge task override' do
    expect(backend_job_tf).to include('command = ["/bin/sh", "-c", "exec ./bin/db-replicate"]')
  end
end
