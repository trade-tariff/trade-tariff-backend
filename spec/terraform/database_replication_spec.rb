# frozen_string_literal: true

RSpec.describe 'database replication Terraform' do # rubocop:disable RSpec/DescribeClass
  let(:backend_job_tf) { Rails.root.join('terraform/backend_job.tf').read }
  let(:iam_tf) { Rails.root.join('terraform/iam.tf').read }

  it 'execs the replication script from the EventBridge task override' do
    expect(backend_job_tf).to include('command = ["/bin/sh", "-c", "exec ./bin/db-replicate"]')
  end

  it 'allows the backend job task role to describe and update ECS services in its cluster' do
    expect(iam_tf).to include('"ecs:DescribeServices"')
    expect(iam_tf).to include('"ecs:UpdateService"')
    expect(iam_tf).to include(
      '"arn:aws:ecs:${var.region}:${local.account_id}:service/trade-tariff-cluster-${var.environment}/*"',
    )
    expect(iam_tf).to include('variable = "ecs:cluster"')
    expect(iam_tf).to include('values   = [data.aws_ecs_cluster.this.arn]')
  end
end
