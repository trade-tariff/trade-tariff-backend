module Reporting
  class AdminReportRegistry
    ReportDefinition = Data.define(:id, :name, :description, :generator, :services, :dependencies) do
      def available_for_service?
        services.include?(TradeTariffBackend.service)
      end

      def report_class
        generator.call
      end

      delegate :available_today?, to: :report_class
      delegate :download_link_today, to: :report_class

      def dependency_labels
        dependencies.to_h { |dependency| [dependency[:id], dependency[:label]] }
      end

      def missing_dependency_ids
        dependencies.filter_map do |dependency|
          dependency[:report].available_today? ? nil : dependency[:id]
        end
      end

      def missing_dependencies
        missing_dependency_ids.map { |id| dependency_labels.fetch(id) }
      end

      def dependencies_missing?
        missing_dependency_ids.any?
      end
    end

    class << self
      def all
        definitions.select(&:available_for_service?)
      end

      def fetch!(id)
        all.find { |report| report.id == id.to_s } || raise(Sequel::NoMatchingRow)
      end

      private

      def definitions
        [
          ReportDefinition.new(
            id: 'commodities',
            name: 'Commodities report',
            description: 'CSV export of the current commodities tree for the selected service.',
            generator: -> { Reporting::Commodities },
            services: %w[uk xi],
            dependencies: [],
          ),
          ReportDefinition.new(
            id: 'basic',
            name: 'Basic tariff data report',
            description: 'CSV export of declarable commodity codes, descriptions, third-country duty and supplementary units.',
            generator: -> { Reporting::Basic },
            services: %w[uk xi],
            dependencies: [],
          ),
          ReportDefinition.new(
            id: 'supplementary_units',
            name: 'Supplementary units report',
            description: 'CSV export of supplementary unit measures for the selected service.',
            generator: -> { Reporting::SupplementaryUnits },
            services: %w[uk xi],
            dependencies: [],
          ),
          ReportDefinition.new(
            id: 'declarable_duties',
            name: 'Declarable duties report',
            description: 'Spreadsheet of declarable commodities with applicable duty measures.',
            generator: -> { Reporting::DeclarableDuties },
            services: %w[uk xi],
            dependencies: [],
          ),
          ReportDefinition.new(
            id: 'prohibitions',
            name: 'Prohibitions report',
            description: 'Spreadsheet of declarable commodities with prohibition and restriction measures.',
            generator: -> { Reporting::Prohibitions },
            services: %w[uk xi],
            dependencies: [],
          ),
          ReportDefinition.new(
            id: 'geographical_area_groups',
            name: 'Geographical area groups report',
            description: 'Spreadsheet of geographical area groups and their member areas.',
            generator: -> { Reporting::GeographicalAreaGroups },
            services: %w[uk xi],
            dependencies: [],
          ),
          ReportDefinition.new(
            id: 'differences',
            name: 'Differences report',
            description: "Spreadsheet highlighting potential UK tariff issues. Depends on today's UK and XI commodities and supplementary units reports.",
            generator: -> { Reporting::Differences },
            services: %w[uk],
            dependencies: [
              { id: 'uk_commodities', label: 'UK commodities report', report: Reporting::Commodities },
              { id: 'xi_commodities', label: 'XI commodities report', report: Reporting::Commodities },
              { id: 'uk_supplementary_units', label: 'UK supplementary units report', report: Reporting::SupplementaryUnits },
              { id: 'xi_supplementary_units', label: 'XI supplementary units report', report: Reporting::SupplementaryUnits },
            ],
          ),
          ReportDefinition.new(
            id: 'category_assessments',
            name: 'Category assessments report',
            description: 'ZIP export of Green Lanes category assessments for Northern Ireland.',
            generator: -> { Reporting::CategoryAssessments },
            services: %w[xi],
            dependencies: [],
          ),
        ]
      end
    end
  end
end
