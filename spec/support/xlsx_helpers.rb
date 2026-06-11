require 'zip'
require 'nokogiri'
require 'cgi'

module XlsxHelpers
  def xlsx_entry(xlsx_data, entry_name)
    content = nil

    Zip::File.open_buffer(StringIO.new(xlsx_data)) do |zip|
      entry = zip.read(entry_name)
      content = entry.respond_to?(:read) ? entry.read : entry
    end

    content
  end

  def worksheet_xml(xlsx_data)
    xlsx_entry(xlsx_data, 'xl/worksheets/sheet1.xml')
  end

  def worksheet_relationships_xml(xlsx_data)
    xlsx_entry(xlsx_data, 'xl/worksheets/_rels/sheet1.xml.rels')
  end

  def worksheet_row_texts(xlsx_data)
    doc = Nokogiri::XML(worksheet_xml(xlsx_data))
    doc.remove_namespaces!

    doc.xpath('//row').map do |row|
      row.xpath('.//t').map(&:text)
    end
  end

  def xml_escape(value)
    CGI.escapeHTML(value)
  end
end

RSpec.configure do |config|
  config.include XlsxHelpers
end
