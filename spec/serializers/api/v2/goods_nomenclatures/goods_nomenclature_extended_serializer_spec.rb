RSpec.describe Api::V2::GoodsNomenclatures::GoodsNomenclatureExtendedSerializer do
  describe '#serializable_hash' do
    subject(:serializable) { described_class.new(gn).serializable_hash[:data] }

    let(:gn) do
      create :commodity,
             :with_description,
             validity_start_date: 2.days.ago.beginning_of_day,
             validity_end_date: 2.days.from_now.end_of_day
    end

    it { is_expected.to include type: :goods_nomenclature }
    it { is_expected.to include id: gn.goods_nomenclature_sid.to_s }

    describe 'attributes' do
      subject { serializable[:attributes] }

      let :attribute_keys do
        %i[
          goods_nomenclature_item_id
          goods_nomenclature_sid
          producline_suffix
          description
          number_indents
          href
          formatted_description
          validity_start_date
          validity_end_date
          declarable
          hierarchical_description
        ]
      end

      it { is_expected.to have_attributes keys: attribute_keys }
      it { is_expected.to include goods_nomenclature_item_id: gn.goods_nomenclature_item_id }
      it { is_expected.to include goods_nomenclature_sid: gn.goods_nomenclature_sid }
      it { is_expected.to include producline_suffix: gn.producline_suffix }
      it { is_expected.to include description: gn.description }
      it { is_expected.to include number_indents: gn.number_indents }
      it { is_expected.to include href: "/uk/api/commodities/#{gn.goods_nomenclature_item_id}" }
      it { is_expected.to include formatted_description: gn.formatted_description }
      it { is_expected.to include validity_start_date: gn.validity_start_date }
      it { is_expected.to include validity_end_date: gn.validity_end_date }
      it { is_expected.to include declarable: true }

      context 'with heading' do
        let(:gn) { create :heading, :with_children }

        it { is_expected.to include href: "/uk/api/headings/#{gn.short_code}" }
        it { is_expected.to include declarable: false }
      end

      context 'with declarable heading' do
        let(:gn) { create :heading }

        it { is_expected.to include href: "/uk/api/headings/#{gn.short_code}" }
        it { is_expected.to include declarable: true }
      end

      context 'with subheading' do
        let(:gn) { create :subheading, :with_children }

        it { is_expected.to include href: "/uk/api/subheadings/#{gn.to_param}" }
        it { is_expected.to include declarable: false }
      end
    end

    describe 'relationships' do
      subject { serializable[:relationships] }

      context 'with parent' do
        let(:gn) { create :commodity, :with_heading }

        let :parent do
          {
            id: gn.heading.goods_nomenclature_sid.to_s,
            type: :goods_nomenclature,
          }
        end

        it { is_expected.to include parent: { data: parent } }
      end

      context 'without parent' do
        it { is_expected.to include parent: { data: nil } }
      end
    end
  end
end
