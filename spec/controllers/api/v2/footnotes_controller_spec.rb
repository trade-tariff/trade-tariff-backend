RSpec.describe Api::V2::FootnotesController, type: :controller do
  subject(:do_response) { get :search, params: query, format: :json && response }

  let(:footnote) { create(:footnote, :with_description) }

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

    it_behaves_like 'a successful jsonapi response'
  end

  context 'when searching by type' do
    let(:query) { { type: footnote.footnote_type_id } }

    it_behaves_like 'a successful jsonapi response'
  end

  context 'when searching by description' do
    let(:query) { { description: footnote.description } }

    it_behaves_like 'a successful jsonapi response'
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
