RSpec.describe Api::V2::SectionsController do
  routes { V2Api.routes }
  # GET /api/sections/:id

  describe '#show' do
    let(:heading) { create :heading, :with_chapter }
    let(:chapter) { heading.reload.chapter }
    let(:chapter_guide) { chapter.guides.first }
    let(:section) { chapter.section }
    let!(:section_note) { create :section_note, section_id: section.id }

    let(:pattern) do
      {
        data: {
          id: section.id.to_s,
          type: 'section',
          attributes: {
            id: section.id,
            position: section.position,
            title: section.title,
            numeral: section.numeral,
            chapter_from: section.chapter_from,
            chapter_to: section.chapter_to,
            description_plain: section.description_plain,
            section_note: section_note.content,
          },
          relationships: {
            chapters: {
              data: [
                {
                  id: chapter.id.to_s,
                  type: 'chapter',
                },
              ],
            },
          },
        },
        included: [
          {
            id: chapter.id.to_s,
            type: 'chapter',
            attributes: {
              goods_nomenclature_sid: chapter.goods_nomenclature_sid,
              goods_nomenclature_item_id: chapter.goods_nomenclature_item_id,
              headings_from: chapter.headings_from,
              headings_to: chapter.headings_to,
              description: chapter.description,
              formatted_description: chapter.formatted_description,
              validity_start_date: chapter.validity_start_date,
              validity_end_date: chapter.validity_end_date,
            },
            relationships: {
              guides: {
                data: [
                  {
                    id: chapter_guide.id.to_s,
                    type: 'guide',
                  },
                ],
              },
            },
          },
          {
            id: chapter_guide.id.to_s,
            type: 'guide',
            attributes: {
              title: chapter_guide.title,
              url: chapter_guide.url,
            },
          },
        ],
      }
    end

    context 'when record is present' do
      it 'returns rendered record' do
        get :show, params: { id: section.position }, format: :json

        expect(response.body).to match_json_expression pattern
      end
    end

    context 'when record is not present' do
      it 'returns not found if record was not found' do
        get :show, params: { id: section.position + 1 }, format: :json

        expect(response.status).to eq 404
      end
    end
  end

  # GET /api/sections
  describe '#index' do
    before { create :section_note, section_id: section1.id }

    let!(:section1)  { create(:chapter, :with_section).section }
    let!(:section2)  { create(:chapter, :with_section).section }

    let(:pattern) do
      {
        data: [
          {
            id: section1.id.to_s,
            type: 'section',
            attributes: {
              id: section1.id,
              position: section1.position,
              title: section1.title,
              numeral: section1.numeral,
              chapter_from: section1.chapter_from,
              chapter_to: section1.chapter_to,
            },
          },
          {
            id: section2.id.to_s,
            type: 'section',
            attributes: {
              id: section2.id,
              position: section2.position,
              title: section2.title,
              numeral: section2.numeral,
              chapter_from: section2.chapter_from,
              chapter_to: section2.chapter_to,
            },
          },
        ],
      }
    end

    it 'returns rendered records' do
      get :index, format: :json

      expect(response.body).to match_json_expression pattern
    end
  end
end
