RSpec.describe Api::V2::FootnotesController, type: :controller do
  routes { V2Api.routes }

  subject(:do_response) { get(:search, params:) && response }

  let(:footnote) { create(:footnote, :with_description) }

  before do
    measure_with_goods_nomenclature = create(:measure, :with_base_regulation, goods_nomenclature: create(:heading, :with_description))
    measure_no_goods_nomenclature = create(:measure, :with_base_regulation, goods_nomenclature: nil)

    create(:footnote_association_goods_nomenclature, footnote:, goods_nomenclature: create(:heading, :with_description))
    create(:footnote_association_goods_nomenclature, footnote:, goods_nomenclature: create(:chapter, :with_description))
    create(:footnote_association_goods_nomenclature, footnote:, goods_nomenclature_sid: '9999') # Broken reference

    create(:footnote_association_measure, measure: measure_with_goods_nomenclature, footnote:)
    create(:footnote_association_measure, measure: measure_no_goods_nomenclature, footnote:)
  end

  context 'when searching by the code and type' do
    let(:params) { { code: footnote.footnote_id, type: footnote.footnote_type_id } }

    it_behaves_like 'a successful jsonapi response'
  end

  context 'when searching by description' do
    let(:params) { { description: footnote.description } }

    it_behaves_like 'a successful jsonapi response'
  end

  context 'when searching by type' do
    let(:params) { { type: footnote.footnote_type_id } }

    let(:pattern) do
      {
        'errors' => [
          {
            'status' => 422,
            'title' => 'is required when filtering by type',
            'detail' => 'Code is required when filtering by type',
          },
        ],
      }
    end

    it { is_expected.to have_http_status :unprocessable_content }
    it { expect(do_response.body).to match_json_expression pattern }
  end

  context 'when searching by id' do
    let(:params) { { code: footnote.footnote_id } }

    let(:pattern) do
      {
        'errors' => [
          {
            'status' => 422,
            'title' => 'is required when filtering by code',
            'detail' => 'Type is required when filtering by code',
          },
        ],
      }
    end

    it { is_expected.to have_http_status :unprocessable_content }
    it { expect(do_response.body).to match_json_expression pattern }
  end

  context 'when searching with no params' do
    let(:params) { {} }

    let(:pattern) do
      {
        'errors' => [
          {
            'status' => 422,
            'title' => 'is required when code and type are missing',
            'detail' => 'Description is required when code and type are missing',
          },
        ],
      }
    end

    it { is_expected.to have_http_status :unprocessable_content }
    it { expect(do_response.body).to match_json_expression pattern }
  end

  context 'when no footnotes are found' do
    let(:params) { { code: 'F-O-O-B-A-R', type: 'FOO' } }

    let(:pattern_empty) do
      {
        data: [],
        included: [],
      }
    end

    it { expect(do_response.body).to match_json_expression pattern_empty }
  end
end
