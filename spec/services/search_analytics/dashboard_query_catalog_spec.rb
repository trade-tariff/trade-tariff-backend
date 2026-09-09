RSpec.describe SearchAnalytics::DashboardQueryCatalog do
  describe '.call' do
    subject(:catalog) { described_class.call(log_group_name: 'platform-logs-staging') }

    let(:captured) { {} }
    let(:status) { instance_double(Process::Status, success?: true) }
    let(:stderr) { '' }
    let(:rendered) do
      {
        'search_dashboard' => { 'Requests' => { 'query_language' => 'SQL', 'query_string' => "SOURCE 'platform-logs-staging' | SELECT COUNT(*) FROM `platform-logs-staging`" } },
        'search_operations_dashboard' => { 'Requests' => { 'query_language' => 'CWLI', 'query_string' => "SOURCE 'platform-logs-staging' | stats count(*)" } },
      }
    end

    before do
      allow(Open3).to receive(:capture3) do |_executable, directory_option, *_arguments|
        captured[:directory] = directory_option.delete_prefix('-chdir=')
        captured[:configuration] = JSON.parse(File.read(File.join(captured[:directory], 'main.tf.json')))
        captured[:lockfile] = File.read(File.join(captured[:directory], '.terraform.lock.hcl'))
        [rendered.to_json.to_json, stderr, status]
      end
    end

    it 'writes an isolated configuration for every dashboard with the selected log group' do
      catalog

      modules = captured[:configuration].fetch('module')
      expect(modules.keys).to contain_exactly('search_dashboard', 'search_quality_dashboard', 'search_experiment_dashboard', 'search_operations_dashboard', 'ai_costs_dashboard')
      modules.each do |name, configuration|
        expect(configuration).to include('environment' => 'validation', 'log_group_name' => 'platform-logs-staging', 'region' => 'eu-west-2')
        expect(File.expand_path(configuration.fetch('source'), captured[:directory])).to eq(Rails.root.join('terraform/modules', name).to_s)
      end
      expect(captured[:configuration].dig('terraform', 'required_providers', 'aws')).to eq('source' => 'hashicorp/aws', 'version' => '~> 5')
      expect(captured[:lockfile]).to eq(Rails.root.join('terraform/.terraform.lock.hcl').read)
      expect(File.exist?(captured[:directory])).to be(false)
    end

    it 'flattens Terraform console output without losing dashboard names, languages or source envelopes' do
      expect(catalog).to eq(
        'search_dashboard/Requests' => rendered.dig('search_dashboard', 'Requests'),
        'search_operations_dashboard/Requests' => rendered.dig('search_operations_dashboard', 'Requests'),
      )
    end

    context 'when Terraform exits unsuccessfully' do
      let(:status) { instance_double(Process::Status, success?: false) }
      let(:stderr) { 'Error: Failed to query available provider packages' }

      it 'propagates the process error and removes its temporary configuration' do
        expect { catalog }.to raise_error(RuntimeError, "Terraform dashboard rendering failed: #{stderr}")
        expect(File.exist?(captured[:directory])).to be(false)
      end
    end
  end
end
