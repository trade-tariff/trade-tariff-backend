RSpec.describe Api::V2::FootnotesController, type: :controller do
  subject(:do_response) { get :search, params: query, format: :json && response }

  let(:footnote) { create(:footnote) }
  let(:pattern) do
    {
      data: [
        {
          id: String,
          type: 'footnote',
          attributes: {
            code: String,
            footnote_type_id: String,
            footnote_id: String,
            description: String,
            formatted_description: String,
            extra_large_measures: false,
          },
          relationships: {
            measures: {
              data: [
                {
                  id: String,
                  type: 'measure',
                },
              ],
            },
            goods_nomenclatures: {
              data: [
                {
                  id: String,
                  type: 'heading',
                },
                {
                  id: String,
                  type: 'chapter',
                },
              ],
            },
          },
        },
      ],
      included: [
        {
          id: String,
          type: 'chapter',
          attributes: {
            goods_nomenclature_item_id: String,
            description: String,
            formatted_description: String,
            producline_suffix: String,
          },
        },
        {
          id: String,
          type: 'heading',
          attributes: {
            goods_nomenclature_item_id: String,
            description: String,
            formatted_description: String,
            producline_suffix: String,
          },
        },
        {
          id: String,
          type: 'heading',
          attributes: {
            goods_nomenclature_item_id: String,
            description: String,
            formatted_description: String,
            producline_suffix: String,
          },
        },
        {
          id: String,
          type: 'measure',
          attributes: {
            goods_nomenclature_item_id: String,
            validity_start_date: String,
            validity_end_date: String,
          },
          relationships: {
            goods_nomenclature: {
              data: {
                id: String,
                type: 'heading',
              },
            },
            geographical_area: {
              data: {
                id: String,
                type: 'geographical_area',
              },
            },
          },
        },
      ],
      meta: {
        pagination: {
          page: Integer,
          per_page: Integer,
          total_count: Integer,
        },
      },
    }
  end

  before do
    measure_with_goods_nomenclature = create(:measure, :with_base_regulation, goods_nomenclature: create(:heading, :with_description))
    measure_no_goods_nomenclature = create(:measure, :with_base_regulation, goods_nomenclature: nil)

    create(:footnote_association_goods_nomenclature, footnote:, goods_nomenclature: create(:heading, :with_description))
    create(:footnote_association_goods_nomenclature, footnote:, goods_nomenclature: create(:chapter, :with_description))
    create(:footnote_association_goods_nomenclature, footnote:, goods_nomenclature_sid: '9999') # Broken reference

    create(:footnote_association_measure, measure: measure_with_goods_nomenclature, footnote:)
    create(:footnote_association_measure, measure: measure_no_goods_nomenclature, footnote:)

    Sidekiq::Testing.inline! do
      TradeTariffBackend.cache_client.reindex(Cache::FootnoteIndex.new)
      sleep(2)
    end
  end

  context 'when searching by the code' do
    let(:query) { { code: footnote.footnote_id } }

    it { expect(do_response.body).to match_json_expression pattern }
  end

  context 'when searching by type' do
    let(:query) { { type: footnote.footnote_type_id } }

    it { expect(do_response.body).to match_json_expression pattern }
  end

  context 'when searching by description' do
    let(:query) { { description: footnote.description } }

    it { expect(do_response.body).to match_json_expression pattern }
  end

  context 'when no footnotes are found' do
    let(:query) { { code: 'F-O-O-B-A-R' } }

    let(:pattern_empty) do
      {
        data: [],
        included: [],
        meta: {
          pagination: {
            page: Integer,
            per_page: Integer,
            total_count: Integer,
          },
        },
      }
    end

    it { expect(do_response.body).to match_json_expression pattern_empty }
  end
end
