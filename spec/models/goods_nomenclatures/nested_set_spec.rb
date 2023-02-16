require 'rails_helper'

RSpec.describe GoodsNomenclatures::NestedSet do
  around { |example| TimeMachine.now { example.run } }

  describe 'relationships' do
    describe '#tree_node' do
      subject(:tree_node) { commodity.reload.tree_node }

      let :commodity do
        create :commodity, :with_indent, goods_nomenclature_item_id: '0101010101',
                                         indents: 1
      end

      let(:indent) { commodity.goods_nomenclature_indent }

      it { is_expected.to be_instance_of GoodsNomenclatures::TreeNode }
      it { is_expected.to have_attributes goods_nomenclature_sid: commodity.goods_nomenclature_sid }
      it { is_expected.to have_attributes depth: 3 }
      it { is_expected.to have_attributes goods_nomenclature_indent_sid: indent.pk }

      it 'reciprocates correctly' do
        expect(tree_node.goods_nomenclature.object_id).to eq commodity.object_id
      end

      context 'with time machine' do
        before { new_indent && commodity.reload }

        let :new_indent do
          create :goods_nomenclature_indent, goods_nomenclature: commodity,
                                             validity_start_date: 1.week.ago,
                                             number_indents: 2
        end

        it { is_expected.to have_attributes goods_nomenclature_indent_sid: new_indent.pk }
        it { is_expected.to have_attributes depth: 4 }

        context 'with date in the past' do
          around { |example| TimeMachine.at(2.weeks.ago) { example.run } }

          it { is_expected.to have_attributes goods_nomenclature_indent_sid: indent.pk }
          it { is_expected.to have_attributes depth: 3 }
        end
      end
    end
  end
end
