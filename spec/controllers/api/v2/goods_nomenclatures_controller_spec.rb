RSpec.describe Api::V2::GoodsNomenclaturesController do
  render_views

  let!(:goods_nomenclature) do
    create :commodity,
           :with_indent,
           :with_chapter,
           :with_heading
  end
  let(:chapter) { goods_nomenclature.reload.chapter }
  let(:heading) { goods_nomenclature.reload.heading }
  let(:section) { goods_nomenclature.chapter.reload.section }
  let(:pattern_section_and_chapter) do
    {
      data: [
        { # goods_nomenclature
          id: goods_nomenclature.id.to_s,
          type: 'goods_nomenclature',
          attributes: {
            goods_nomenclature_sid: goods_nomenclature.goods_nomenclature_sid,
            goods_nomenclature_item_id: goods_nomenclature.goods_nomenclature_item_id,
            description: goods_nomenclature.description,
            number_indents: goods_nomenclature.number_indents,
            producline_suffix: goods_nomenclature.producline_suffix,
            href: described_class.api_path_builder(goods_nomenclature),
          },
        },
        { # heading
          id: heading.id.to_s,
          type: 'goods_nomenclature',
          attributes: {
            goods_nomenclature_sid: heading.goods_nomenclature_sid,
            goods_nomenclature_item_id: heading.goods_nomenclature_item_id,
            description: heading.description,
            number_indents: Integer,
            producline_suffix: heading.producline_suffix,
            href: described_class.api_path_builder(heading),
          },
        },
        { # chapter
          id: chapter.id.to_s,
          type: 'goods_nomenclature',
          attributes: {
            goods_nomenclature_sid: chapter.goods_nomenclature_sid,
            goods_nomenclature_item_id: chapter.goods_nomenclature_item_id,
            description: chapter.description,
            number_indents: Integer,
            producline_suffix: chapter.producline_suffix,
            href: described_class.api_path_builder(chapter),
          },
        },
      ],
    }
  end
  let(:pattern_heading) do
    {
      data: [
        { # goods_nomenclature
          id: goods_nomenclature.id.to_s,
          type: 'goods_nomenclature',
          attributes: {
            goods_nomenclature_sid: goods_nomenclature.goods_nomenclature_sid,
            goods_nomenclature_item_id: goods_nomenclature.goods_nomenclature_item_id,
            description: goods_nomenclature.description,
            number_indents: goods_nomenclature.number_indents,
            producline_suffix: goods_nomenclature.producline_suffix,
            href: described_class.api_path_builder(goods_nomenclature),
          },
        },
        { # heading
          id: heading.id.to_s,
          type: 'goods_nomenclature',
          attributes: {
            goods_nomenclature_sid: heading.goods_nomenclature_sid,
            goods_nomenclature_item_id: heading.goods_nomenclature_item_id,
            description: heading.description,
            number_indents: Integer,
            producline_suffix: heading.producline_suffix,
            href: described_class.api_path_builder(heading),
          },
        },
      ],
    }
  end
  let(:csv_first_row) { 'SID,Goods Nomenclature Item ID,Indents,Description,Product Line Suffix,Href' }
  let(:csv_chapter_row) { "#{chapter.goods_nomenclature_sid},#{chapter.goods_nomenclature_item_id},1,\"\",#{chapter.producline_suffix},#{described_class.api_path_builder(chapter)}" }
  let(:csv_heading_row) { "#{heading.goods_nomenclature_sid},#{heading.goods_nomenclature_item_id},1,\"\",#{heading.producline_suffix},#{described_class.api_path_builder(heading)}" }
  let(:csv_commodity_row) { "#{goods_nomenclature.goods_nomenclature_sid},#{goods_nomenclature.goods_nomenclature_item_id},#{goods_nomenclature.number_indents},\"\",#{goods_nomenclature.producline_suffix},#{described_class.api_path_builder(goods_nomenclature)}" }

  context 'when GNs for a section are requested' do
    context 'with a correct short code' do
      it 'returns rendered record of GNs in the section' do
        get :show_by_section, params: { position: section.position }, format: :json

        expect(response.body).to match_json_expression pattern_section_and_chapter
      end
    end

    context 'with an incorrect short code' do
      it 'returns a 404' do
        get :show_by_section, params: { position: '99' }, format: :json

        expect(response.status).to eq 404
      end
    end
  end

  context 'when GNs for a section are requested as CSV' do
    it 'returns rendered record of GNs in the section as CSV' do
      get :show_by_section, params: { position: section.position }, format: :csv

      expect(response.body).to match("#{csv_first_row}\n#{csv_chapter_row}\n#{csv_heading_row}\n#{csv_commodity_row}")
    end
  end

  context 'when GNs for a chapter are requested' do
    it 'returns rendered record of GNs in the chapter' do
      get :show_by_chapter, params: { chapter_id: chapter.short_code }, format: :json

      expect(response.body).to match_json_expression pattern_section_and_chapter
    end
  end

  context 'when GNs for a chapter are requested as CSV' do
    it 'returns rendered record of GNs in the chapter as CSV' do
      get :show_by_chapter, params: { chapter_id: chapter.short_code }, format: :csv

      expect(response.body).to match("#{csv_first_row}\n#{csv_chapter_row}\n#{csv_heading_row}\n#{csv_commodity_row}")
    end
  end

  context 'when GNs for a heading are requested' do
    context 'with a correct short code' do
      it 'returns rendered record of GNs in the heading' do
        get :show_by_heading, params: { heading_id: heading.short_code }, format: :json

        expect(response.body).to match_json_expression pattern_heading
      end
    end

    context 'with an incorrect short code' do
      it 'returns a 404' do
        expect { get :show_by_heading, params: { heading_id: '0' }, format: :json }.to raise_error(ActionController::UrlGenerationError)
      end
    end
  end

  context 'when GNs for a heading are requested as CSV' do
    it 'returns rendered record of GNs in the heading as CSV' do
      get :show_by_heading, params: { heading_id: heading.short_code }, format: :csv

      expect(response.body).to match("#{csv_first_row}\n#{csv_heading_row}\n#{csv_commodity_row}")
    end
  end
end
