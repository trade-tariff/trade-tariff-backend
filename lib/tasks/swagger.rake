require 'json'

namespace :swagger do
  swagger_spec_pattern = 'spec/swagger/**/*_spec.rb'
  swagger_json_path = File.expand_path('../../swagger/v2/swagger.json', __dir__)

  # Paths that have specs (useful for contract testing) but must not appear in
  # the public API docs — either because they are internal-only endpoints or
  # because they are no longer active.
  internal_paths = %w[
    /uk/api/commodities/{commodity_id}/validity_periods
    /uk/api/headings/{heading_id}/validity_periods
    /uk/api/monetary_exchange_rates
    /uk/api/preference_codes
    /uk/api/preference_codes/{id}
    /uk/api/simplified_procedural_code_measures
    /uk/api/subheadings/{subheading_id}/validity_periods
    /uk/api/updates/latest
  ].freeze

  # Sort paths alphabetically so the generated JSON is deterministic across
  # platforms regardless of the order Dir.glob returns spec files.
  # Also strips internal/dead paths that must not appear in the public docs.
  post_process = lambda do
    next unless File.exist?(swagger_json_path)

    doc = JSON.parse(File.read(swagger_json_path))
    if doc['paths']
      doc['paths'] = doc['paths']
        .reject { |path, _| internal_paths.include?(path) }
        .sort
        .to_h
    end
    File.write(swagger_json_path, "#{JSON.pretty_generate(doc)}\n")
  end

  desc 'Generate swagger documentation from spec metadata (no database required)'
  task :generate do
    ENV['PATTERN'] = swagger_spec_pattern
    Rake::Task['rswag:specs:swaggerize'].invoke
    post_process.call
  end

  desc 'Check every public V2 controller has a swagger spec (intended for CI)'
  task :check_coverage do
    controller_root = File.expand_path('../../app/controllers/api/v2', __dir__)
    spec_root = File.expand_path('../../spec/swagger/api/v2', __dir__)

    # Controllers that are deliberately not documented:
    #   - abstract base classes that define no routes of their own
    #   - internal/authenticated endpoints not part of the public API
    excluded = %w[
      exchange_rates/base_controller.rb
      green_lanes/base_controller.rb
      green_lanes/faq_feedback_controller.rb
      green_lanes/goods_nomenclatures_controller.rb
      green_lanes/themes_controller.rb
      enquiry_form/submissions_controller.rb
      errors_controller.rb
      notifications_controller.rb
      search_controller.rb
    ].freeze

    # Controllers whose actions are documented together in one combined spec
    # rather than a file-per-controller.
    combined = {
      'news/collections_controller.rb' => 'news_spec.rb',
      'news/items_controller.rb' => 'news_spec.rb',
      'news/years_controller.rb' => 'news_spec.rb',
      'exchange_rates/files_controller.rb' => 'exchange_rates_spec.rb',
      'exchange_rates/period_lists_controller.rb' => 'exchange_rates_spec.rb',
      'rules_of_origin/product_specific_rules_controller.rb' => 'rules_of_origin_spec.rb',
      'rules_of_origin/schemes_controller.rb' => 'rules_of_origin_spec.rb',
    }.freeze

    controllers = Dir.glob("#{controller_root}/**/*_controller.rb").map do |path|
      path.delete_prefix("#{controller_root}/")
    end

    missing = controllers.reject do |controller|
      next true if excluded.include?(controller)

      if combined.key?(controller)
        File.exist?(File.join(spec_root, combined[controller]))
      else
        spec_name = controller.sub(/_controller\.rb$/, '_spec.rb')
        File.exist?(File.join(spec_root, spec_name))
      end
    end

    if missing.empty?
      puts 'All public V2 controllers have swagger specs.'
    else
      warn "The following V2 controllers have no swagger spec:\n"
      missing.each { |c| warn "  app/controllers/api/v2/#{c}" }
      warn "\nAdd a spec under spec/swagger/api/v2/ or add the controller"
      warn 'to the excluded/combined lists in lib/tasks/swagger.rake.'
      exit 1
    end
  end
end
