RSpec.describe Api::V2::Footnotes::FootnoteSerializer do
  subject(:serializer) { described_class.new(serializable).serializable_hash.as_json }

  let(:serializable) do
    cache_serialized_footnote = Cache::FootnoteSerializer.new(footnote).as_json

    Hashie::TariffMash.new(cache_serialized_footnote)
  end

  let(:footnote) { create(:footnote) }

  describe '#serializable_hash' do
    context 'when there are associated goods nomenclature' do
      before do
        create(
          :footnote_association_goods_nomenclature,
          footnote:,
          goods_nomenclature: create(:heading),
        )

        create(
          :footnote_association_measure,
          footnote:,
          measure: create(:measure, goods_nomenclature: create(:chapter)),
        )
      end

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
              extra_large_measures: false,
            },
            relationships: {
              measures: { data: [{ id: String, type: 'measure' }] },
              goods_nomenclatures: { data: [{ id: String, type: 'heading' }] },
            },
          },
        }
      end

      it { is_expected.to match_json_expression(expected_pattern) }
    end

    context 'when goods nomenclature references are broken' do
      before do
        create(
          :footnote_association_goods_nomenclature,
          footnote:,
          goods_nomenclature_sid: '9999',
        )

        create(
          :footnote_association_measure,
          footnote:,
          measure: create(:measure, goods_nomenclature: nil),
        )
      end

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
              extra_large_measures: false,
            },
            relationships: {
              goods_nomenclatures: { data: [] },
              measures: { data: [] },
            },
          },
        }
      end

      it { is_expected.to match_json_expression(expected_pattern) }
    end
  end
end
