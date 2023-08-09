RSpec.describe Api::V2::Footnotes::FootnoteSerializer do
  subject(:serializer) { described_class.new(serializable).serializable_hash.as_json }

  let(:serializable) do
    footnote = create(:footnote, :with_description)
    goods_nomenclatures = create_list(:heading, 1)

    Api::V2::FootnoteSearch::FootnotePresenter.new(footnote, goods_nomenclatures)
  end

  describe '#serializable_hash' do
    let(:expected_pattern) do
      {
        data: {
          id: String,
          type: 'footnote',
          attributes: {
            code: String,
            footnote_type_id: String,
            footnote_id: String,
            description: String,
            formatted_description: String,
            validity_start_date: /\d{4}-\d{2}-\d{2}T00:00:00.000Z/,
            validity_end_date: nil,
          },
          relationships: {
            goods_nomenclatures: { data: [{ id: String, type: 'heading' }] },
          },
        },
      }
    end

    it { is_expected.to match_json_expression(expected_pattern) }
  end
end
