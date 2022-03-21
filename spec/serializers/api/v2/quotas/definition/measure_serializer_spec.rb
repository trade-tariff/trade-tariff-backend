RSpec.describe Api::V2::Quotas::Definition::MeasureSerializer do
  subject(:serializer) { described_class.new(serializable, {}) }

  let(:serializable) { create(:measure, goods_nomenclature:) }

  describe '#serializable_hash' do
    shared_examples_for 'a measure with a polymorphic goods nomenclature' do |polymorphic_type|
      let(:expected_pattern) do
        {
          data: {
            id: serializable.measure_sid.to_s,
            type: 'measure',
            attributes: {
              goods_nomenclature_item_id: match(/\d{10}/),
            },
            relationships: {
              geographical_area: {
                data: {
                  id: serializable.geographical_area_id,
                  type: 'geographical_area',
                },
              },
              goods_nomenclature: {
                data: {
                  id: goods_nomenclature.goods_nomenclature_sid.to_s,
                  type: polymorphic_type,
                },
              },
            },
          },
        }
      end

      it { expect(serializer.serializable_hash.as_json).to include_json(expected_pattern) }
    end

    it_behaves_like 'a measure with a polymorphic goods nomenclature', 'commodity' do
      let(:goods_nomenclature) { create(:commodity, :declarable, :with_heading) }
    end

    it_behaves_like 'a measure with a polymorphic goods nomenclature', 'subheading' do
      let(:goods_nomenclature) { create(:commodity, :non_declarable, :with_heading) }
    end

    it_behaves_like 'a measure with a polymorphic goods nomenclature', 'heading' do
      let(:goods_nomenclature) { create(:heading) }
    end

    it_behaves_like 'a measure with a polymorphic goods nomenclature', 'chapter' do
      let(:goods_nomenclature) { create(:chapter) }
    end
  end
end
