RSpec.describe Api::V2::SubheadingsController, :v2 do
  describe 'GET #show' do
    subject(:rendered) { make_request && response } # Subheading api requires the producline suffix to identify the subheading

    let(:make_request) { get api_subheading_path('0101210000-10') }

    context 'when the subheading has at least one child, a heading, a chapter and a section' do
      before do
        create(:chapter, :with_section, :with_indent, :with_guide, goods_nomenclature_sid: 1, indents: 0, producline_suffix: '80', goods_nomenclature_item_id: '0100000000') # Live animals
        create(:heading, :with_indent, :with_description, goods_nomenclature_sid: 2, indents: 0, producline_suffix: '80', goods_nomenclature_item_id: '0101000000')
        create(:commodity, :with_indent, :with_description, goods_nomenclature_sid: 3, indents: 1, producline_suffix: '10', goods_nomenclature_item_id: '0101210000')
        create(:commodity, :with_indent, :with_description, goods_nomenclature_sid: 4, indents: 2, producline_suffix: '80', goods_nomenclature_item_id: '0101210000')
      end

      it_behaves_like 'a successful jsonapi response'
    end

    context 'when the subheading has no children' do
      before do
        create(:heading, :with_indent, :with_description, goods_nomenclature_sid: 2, indents: 0, producline_suffix: '80', goods_nomenclature_item_id: '0101000000')
        create(:commodity, :with_indent, :with_description, goods_nomenclature_sid: 3, indents: 1, producline_suffix: '10', goods_nomenclature_item_id: '0101210000')
      end

      it { is_expected.to have_http_status(:not_found) }
    end
  end
end
