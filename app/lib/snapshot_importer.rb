require 'active_support/core_ext/hash/conversions'
require_relative 'snapshot/loaders/base'

Dir[Rails.root.join('app/lib/snapshot/loaders/**/*.rb')].sort.each { |f| require f }

class SnapshotImporter
  class ImportException < StandardError; end

  FILE = '/Users/rasika.abeyrathna/dev/HMRC/yearly.xml'.freeze

  def nodes
    Loaders.constants.dup.map(&:to_s).delete_if { |name| name == 'Base' }
  end

  def perform
    Object.const_get('FootnoteType::Operation').truncate
    Object.const_get('FootnoteTypeDescription::Operation').truncate
    Object.const_get('CertificateType::Operation').truncate
    Object.const_get('CertificateTypeDescription::Operation').truncate
    Object.const_get('AdditionalCodeType::Operation').truncate
    Object.const_get('AdditionalCodeTypeDescription::Operation').truncate
    Object.const_get('AdditionalCodeTypeMeasureType::Operation').truncate
    Object.const_get('Measure::Operation').truncate
    Object.const_get('MeasureComponent::Operation').truncate

    file_name = FILE.split('/').last
    File.open(FILE) do |file|
      current_node = ''
      count = 0
      batch = []

      Nokogiri::XML::Reader.from_io(file).each do |node|
        next unless nodes.include? node.name

        if !batch.empty? && (current_node != node.name || count % 100 == 0)
          puts "Loading #{current_node}"
          loader = Object.const_get("Loaders::#{current_node}")
          loader.load(file_name, batch)
          batch.clear
        end

        # Process current node
        attribs = Hash.from_xml(node.outer_xml)
        batch << attribs if attribs[node.name]
        current_node = node.name
        count += 1
      end

      unless batch.empty?
        puts "Loading #{current_node}"
        loader = Object.const_get("Loaders::#{current_node}")
        loader.load(file_name, batch)
      end
    end
    puts 'Done' # rubocop:disable Rails/Output
  end
end
