# frozen_string_literal: true

require 'open3'
require 'tmpdir'

module SearchAnalytics
  class DashboardQueryCatalog
    DASHBOARDS = %w[search_dashboard search_quality_dashboard search_experiment_dashboard search_operations_dashboard ai_costs_dashboard].freeze

    def self.call(log_group_name:)
      Dir.mktmpdir('search-dashboard-queries') do |directory|
        configuration = {
          terraform: { required_providers: { aws: { source: 'hashicorp/aws', version: '~> 5' } } },
          module: DASHBOARDS.index_with do |name|
            source = Rails.root.join('terraform/modules', name).relative_path_from(Pathname.new(directory)).to_s
            { source:, environment: 'validation', log_group_name:, region: 'eu-west-2' }
          end,
        }
        File.write(File.join(directory, 'main.tf.json'), configuration.to_json)
        FileUtils.cp(Rails.root.join('terraform/.terraform.lock.hcl'), directory)
        run(directory, 'init', '-backend=false', '-input=false', '-no-color')
        run(directory, 'validate', '-no-color')
        expression = DASHBOARDS.map { |name| "#{name} = module.#{name}.queries" }.join(', ')
        rendered = run(directory, 'console', '-no-color', stdin_data: "jsonencode({#{expression}})\n")
        JSON.parse(JSON.parse(rendered)).each_with_object({}) do |(dashboard, queries), catalog|
          queries.each { |title, query| catalog["#{dashboard}/#{title}"] = query }
        end
      end
    end

    def self.run(directory, *arguments, **options)
      output, error, status = Open3.capture3('terraform', "-chdir=#{directory}", *arguments, **options)
      raise "Terraform dashboard rendering failed: #{error.presence || output}" unless status.success?

      output
    end
    private_class_method :run
  end
end
