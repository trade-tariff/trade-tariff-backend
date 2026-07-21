require 'json'

module SwaggerRakeTasks
  SWAGGER_SPEC_PATTERN = 'spec/swagger/**/*_spec.rb'.freeze
  SWAGGER_JSON_PATH = File.expand_path('../../swagger/v2/swagger.json', __dir__)
  DRAFT_SWAGGER_SPECS = %w[
    spec/swagger/api/v2/classification_search_spec.rb
  ].freeze

  # Paths that have specs (useful for contract testing) but must not appear in
  # the public API docs. Excluded because they are frontend-internal endpoints
  # (zero or near-zero external API usage) or have no observed traffic at all.
  #
  # Classification is based on 90 days of CloudWatch traffic data.
  # Paths are relative to the server base URL (no /uk or /xi prefix).
  #
  # To re-evaluate: compare non-frontend vs frontend request counts. Any path
  # with meaningful non-frontend traffic belongs in the public docs, not here.
  INTERNAL_PATHS = %w[
    /api/chemicals/{id}
    /api/classification_search
    /api/commodities/{commodity_id}/validity_periods
    /api/headings/{heading_id}/validity_periods
    /api/news/items/{id}
    /api/news/years
    /api/preference_codes/{id}
    /api/sections/{id}/chapters
    /api/subheadings/{subheading_id}/validity_periods
  ].freeze

  # Controllers that are deliberately not documented:
  #   - abstract base classes that define no routes of their own
  #   - internal/authenticated endpoints not part of the public API
  #   - draft MCP-facing APIs that should not be published until release
  EXCLUDED_CONTROLLERS = %w[
    classification_search_controller.rb
    exchange_rates/base_controller.rb
    green_lanes/base_controller.rb
    green_lanes/faq_feedback_controller.rb
    green_lanes/goods_nomenclatures_controller.rb
    green_lanes/themes_controller.rb
    knowledge_graph/queries_controller.rb
    enquiry_form/revised_submissions_controller.rb
    enquiry_form/submissions_controller.rb
    errors_controller.rb
    notifications_controller.rb
  ].freeze

  # Controllers whose actions are documented together in one combined spec
  # rather than a file-per-controller.
  COMBINED_CONTROLLER_SPECS = {
    'news/collections_controller.rb' => 'news_spec.rb',
    'news/items_controller.rb' => 'news_spec.rb',
    'news/years_controller.rb' => 'news_spec.rb',
    'exchange_rates/files_controller.rb' => 'exchange_rates_spec.rb',
    'exchange_rates/period_lists_controller.rb' => 'exchange_rates_spec.rb',
    'rules_of_origin/product_specific_rules_controller.rb' => 'rules_of_origin_spec.rb',
    'rules_of_origin/schemes_controller.rb' => 'rules_of_origin_spec.rb',
  }.freeze

  CONTROLLER_ROOT = File.expand_path('../../app/controllers/api/v2', __dir__)
  SPEC_ROOT = File.expand_path('../../spec/swagger/api/v2', __dir__)

module_function

  def generate
    ENV['PATTERN'] = Dir.glob(SWAGGER_SPEC_PATTERN).reject { |path| DRAFT_SWAGGER_SPECS.include?(path) }.join(',')
    Rake::Task['rswag:specs:swaggerize'].invoke
    post_process
  end

  # Sort paths alphabetically so the generated JSON is deterministic across
  # platforms regardless of the order Dir.glob returns spec files.
  # Also strips internal/dead paths that must not appear in the public docs.
  def post_process
    return unless File.exist?(SWAGGER_JSON_PATH)

    doc = remove_rswag_getters(JSON.parse(File.read(SWAGGER_JSON_PATH)))
    doc['paths'] = public_paths(doc['paths']) if doc['paths']
    File.write(SWAGGER_JSON_PATH, "#{JSON.pretty_generate(doc)}\n")
  end

  def remove_rswag_getters(value)
    # `getter` maps OpenAPI names to Ruby helpers while specs run, but is not
    # part of the OpenAPI schema and rswag retains it on path-level parameters.
    case value
    when Hash
      value.each_with_object({}) do |(key, child), result|
        result[key] = remove_rswag_getters(child) unless key == 'getter'
      end
    when Array
      value.map { |child| remove_rswag_getters(child) }
    else
      value
    end
  end

  def public_paths(paths)
    paths
      .reject { |path, _| INTERNAL_PATHS.include?(path) }
      .sort
      .to_h
  end

  def check_coverage
    missing = missing_controller_specs
    return puts('All public V2 controllers have swagger specs.') if missing.empty?

    report_missing_specs(missing)
  end

  def missing_controller_specs
    controllers.reject do |controller|
      EXCLUDED_CONTROLLERS.include?(controller) || spec_exists_for?(controller)
    end
  end

  def controllers
    Dir.glob("#{CONTROLLER_ROOT}/**/*_controller.rb").map do |path|
      path.delete_prefix("#{CONTROLLER_ROOT}/")
    end
  end

  def spec_exists_for?(controller)
    if COMBINED_CONTROLLER_SPECS.key?(controller)
      File.exist?(File.join(SPEC_ROOT, COMBINED_CONTROLLER_SPECS[controller]))
    else
      spec_name = controller.sub(/_controller\.rb$/, '_spec.rb')
      File.exist?(File.join(SPEC_ROOT, spec_name))
    end
  end

  def report_missing_specs(missing)
    warn "The following V2 controllers have no swagger spec:\n"
    missing.each { |controller| warn "  app/controllers/api/v2/#{controller}" }
    warn "\nAdd a spec under spec/swagger/api/v2/ or add the controller"
    warn 'to the excluded/combined lists in lib/tasks/swagger.rake.'
    exit 1
  end
end

namespace :swagger do
  desc 'Generate swagger documentation from spec metadata (no database required)'
  task :generate do
    SwaggerRakeTasks.generate
  end

  desc 'Check every public V2 controller has a swagger spec (intended for CI)'
  task :check_coverage do
    SwaggerRakeTasks.check_coverage
  end
end
