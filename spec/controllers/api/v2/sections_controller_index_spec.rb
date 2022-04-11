RSpec.describe Api::V2::SectionsController, 'GET #index' do
  before { section }

  let(:section) do
    create(
      :section,
      id: 18,
      position: 18,
      numeral: 'XVIII',
      title: 'Optical, photographic, cinematographic, measuring',
    )
  end

  context 'when the format is json' do
    subject(:do_response) { get :index, format: :json }

    let(:pattern) do
      {
        data: [
          {
            id: section.id.to_s,
            type: 'section',
            attributes: {
              id: section.id,
              position: section.position,
              title: section.title,
              numeral: section.numeral,
              chapter_from: section.chapter_from,
              chapter_to: section.chapter_to,
            },
          },
        ],
      }
    end

    it { expect(do_response.body).to match_json_expression pattern }
  end

  context 'when the format is csv' do
    subject(:do_response) { get :index, format: :csv }

    render_views

    let(:expected_csv) { "id,numeral,title,position,chapter_from,chapter_to\n18,XVIII,\"Optical, photographic, cinematographic, measuring\",18,,\n" }

    it { expect(do_response.body).to eq(expected_csv) }
  end
end
