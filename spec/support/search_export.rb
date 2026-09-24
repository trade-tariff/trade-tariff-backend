RSpec.shared_context 'with workbook exports' do
  let(:workbook_exports) { [] }

  before do
    allow(SearchExport::WorkbookExport).to receive(:create).and_wrap_original do |method, **attributes|
      method.call(**attributes).tap { |export| workbook_exports << export }
    end
  end

  after { workbook_exports.each(&:delete) }
end
