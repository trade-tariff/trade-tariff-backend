RSpec.describe Api::V2::SectionsController do
  describe '#show' do
    let(:heading) { create :heading, :with_chapter }
    let(:chapter) { heading.reload.chapter }
    let(:chapter_guide) { chapter.guides.first }
    let(:section) { chapter.section }
    let!(:customs_tariff_update) { create(:customs_tariff_update, :approved) }
    let!(:customs_tariff_section_note) do
      create(:customs_tariff_section_note, :approved,
             customs_tariff_update:,
             section_id: section.id)
    end

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
            section_note: customs_tariff_section_note.content,
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
      it 'returns api_response record' do
        get "/uk/api/sections/#{section.position}.json", headers: request_headers(format: :json)

        expect(response.body).to match_json_expression pattern
      end
    end

    context 'when record is not present' do
      it 'returns not found if record was not found' do
        get "/uk/api/sections/#{section.position + 1}.json", headers: request_headers(format: :json)

        expect(response.status).to eq 404
      end
    end

    context 'when id is not numeric' do
      it 'returns bad request' do
        get '/uk/api/sections/VII.json', headers: request_headers(format: :json)

        expect(response.status).to eq 400
      end
    end
  end

  describe '#index' do
    before { create :section_note, section_id: first_section.id }

    let!(:first_section) { create(:chapter, :with_section).section }
    let!(:second_section) { create(:chapter, :with_section).section }

    let(:pattern) do
      {
        data: [
          {
            id: first_section.id.to_s,
            type: 'section',
            attributes: {
              id: first_section.id,
              position: first_section.position,
              title: first_section.title,
              numeral: first_section.numeral,
              chapter_from: first_section.chapter_from,
              chapter_to: first_section.chapter_to,
            },
          },
          {
            id: second_section.id.to_s,
            type: 'section',
            attributes: {
              id: second_section.id,
              position: second_section.position,
              title: second_section.title,
              numeral: second_section.numeral,
              chapter_from: second_section.chapter_from,
              chapter_to: second_section.chapter_to,
            },
          },
        ],
      }
    end

    it 'returns api_response records' do
      get '/uk/api/sections.json', headers: request_headers(format: :json)

      expect(response.body).to match_json_expression pattern
    end
  end
end
