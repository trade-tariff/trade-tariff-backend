require_relative 'admin_configuration_seeder/config_registry'

module AdminConfigurationSeeder
module_function

  def seed
    created = ConfigRegistry.configs.sum { |attrs| create_or_patch(attrs) }
    created += patch_retrieval_method

    output "  created #{created} configuration(s)" if created.positive?
  end

  def create_or_patch(attrs)
    config = AdminConfiguration.where(name: attrs[:name]).first
    return create_config(attrs) unless config

    patch_config_type(config, attrs)
  end

  def create_config(attrs)
    AdminConfiguration.create(attrs.merge(area: 'classification'))
    output "  created: #{attrs[:name]}"
    1
  end

  def patch_config_type(config, attrs)
    if config.config_type == attrs[:config_type]
      output "  skip: #{attrs[:name]} (already exists)"
      return 0
    end

    config.update(config_type: attrs[:config_type], value: attrs[:value])
    output "  patched: #{attrs[:name]} (config type)"
    1
  end

  def patch_retrieval_method
    retrieval = AdminConfiguration.where(name: 'retrieval_method').first
    return 0 unless retrieval

    options = retrieval.value['options'] || []
    return 0 if options.any? { |option| option['key'] == 'hybrid' }

    options << { 'key' => 'hybrid', 'label' => 'Hybrid (text + vector with RRF fusion)' }
    retrieval.update(value: Sequel.pg_jsonb_wrap(retrieval.value.to_hash.merge('options' => options)))
    output '  patched: retrieval_method (added hybrid option)'
    1
  end

  def output(message)
    $stdout.puts(message)
  end
end
