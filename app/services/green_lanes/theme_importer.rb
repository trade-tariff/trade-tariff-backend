require 'nokogiri'

module GreenLanes
  class ThemeImporter
    class << self
      def call
        raise 'Not in XI environment' unless TradeTariffBackend.xi?

        source_file = Rails.root.join('data/green_lanes/themes.html')
        raise "Cannot read file '#{source_file}'" unless File.file?(source_file)

        existing_themes = GreenLanes::Theme.all.index_by { |theme| [theme.section, theme.subsection] }

        GreenLanes::Theme.db.transaction do
          import_nodes(Nokogiri::HTML(source_file.read), existing_themes)
        end
      end

    private

      def import_nodes(source_doc, existing_themes)
        section = nil
        source_doc.css('div#anx_IV p.oj-ti-grseq-1,div#anx_IV table').each do |node|
          section = import_node(node, section, existing_themes)
        end
      end

      def import_node(node, section, existing_themes)
        case node.name
        when 'p'
          node.content.strip.gsub(/Category /, '').to_i
        when 'table'
          import_table(node, section, existing_themes)
          section
        else
          section
        end
      end

      def import_table(node, section, existing_themes)
        cells = node.css('td')
        subsection = cells[0].content.strip.gsub(/\.$/, '').to_i
        description = cells[1].content.strip
        instance = existing_themes[[section, subsection]] || GreenLanes::Theme.new(section:, subsection:)

        instance.theme = description.slice(0, 254)
        instance.description = description
        instance.category = section
        instance.save(raise_on_failure: true)
      end
    end
  end
end
