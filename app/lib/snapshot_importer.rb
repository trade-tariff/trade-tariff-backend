require 'active_support/core_ext/hash/conversions'
require_relative 'snapshot/loaders/base'

Dir[Rails.root.join('app/lib/snapshot/loaders/**/*.rb')].sort.each { |f| require f }

class SnapshotImporter
  class ImportException < StandardError; end

  FILE = '/Users/neil.middleton/Downloads/yearly.xml'.freeze

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

    File.open(FILE) do |file|
      Nokogiri::XML::Reader.from_io(file).each do |node|
        next unless nodes.include? node.name

        attribs = Hash.from_xml(node.outer_xml)
        next if attribs[node.name].nil?

        puts "Loading #{node.name}" # rubocop:disable Rails/Output
        Object.const_get("Loaders::#{node.name}").load(FILE.split('/').last, attribs)
      end
    end
    puts 'Done' # rubocop:disable Rails/Output
  end
end
