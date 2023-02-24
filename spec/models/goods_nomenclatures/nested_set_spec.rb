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

    describe 'hierarchy' do
      let :tree do
        chapter = create(:chapter)
        heading = create(:heading, parent: chapter)
        subheading = create(:commodity, parent: heading)
        subsubheading = create(:commodity, parent: subheading)
        commodity1 = create(:commodity, parent: subsubheading)
        commodity2 = create(:commodity, parent: subsubheading)
        commodity3 = create(:commodity, parent: subheading)
        second_tree = create(:commodity, :with_chapter_and_heading, :with_children)

        {
          chapter:,
          heading:,
          subheading:,
          subsubheading:,
          commodity1:,
          commodity2:,
          commodity3:,
          second_tree:,
        }
      end

      shared_examples 'it has ancestors' do |context_name, node, ancestors|
        context "with #{context_name}" do
          subject { tree[node].ns_ancestors.map(&:goods_nomenclature_sid) }

          it { is_expected.to eq tree.values_at(*ancestors).map(&:goods_nomenclature_sid) }
        end
      end

      shared_examples 'it has parent' do |context_name, node, parent_node|
        context "with #{context_name}" do
          subject { tree[node].ns_parent&.goods_nomenclature_sid }

          it { is_expected.to eq tree[parent_node]&.goods_nomenclature_sid }
        end
      end

      shared_examples 'it has descendants' do |context_name, node, descendants|
        context "with #{context_name}" do
          subject { tree[node].ns_descendants.map(&:goods_nomenclature_sid) }

          it { is_expected.to eq tree.values_at(*descendants).map(&:goods_nomenclature_sid) }
        end
      end

      describe '#ns_ancestors' do
        let(:third_tier_ancestors) { tree.values_at(:chapter, :heading, :subheading) }

        it_behaves_like 'it has ancestors', 'chapter', :chapter, []
        it_behaves_like 'it has ancestors', 'heading', :heading, %i[chapter]
        it_behaves_like 'it has ancestors', 'subheading', :subheading, %i[chapter heading]
        it_behaves_like 'it has ancestors', 'nested subheading', :subsubheading, %i[chapter heading subheading]
        it_behaves_like 'it has ancestors', 'leaf commodity', :commodity1, %i[chapter heading subheading subsubheading]
        it_behaves_like 'it has ancestors', 'second leaf commodity', :commodity3, %i[chapter heading subheading]

        context 'for second tree' do
          subject { tree[:second_tree].ns_ancestors.map(&:goods_nomenclature_item_id) }

          let(:commodity) { tree[:second_tree] }

          let(:expected_ancestor_item_ids) do
            [
              "#{commodity.goods_nomenclature_item_id.first(2)}00000000",
              "#{commodity.goods_nomenclature_item_id.first(4)}000000",
            ]
          end

          it { is_expected.to eq expected_ancestor_item_ids }
        end
      end

      describe '#ns_parent' do
        it_behaves_like 'it has parent', 'chapter', :chapter, nil
        it_behaves_like 'it has parent', 'heading', :heading, :chapter
        it_behaves_like 'it has parent', 'subheading', :subheading, :heading
        it_behaves_like 'it has parent', 'nested heading', :subsubheading, :subheading
        it_behaves_like 'it has parent', 'leaf commodity', :commodity1, :subsubheading
        it_behaves_like 'it has parent', 'second leaf commodity', :commodity3, :subheading

        context 'for second tree' do
          subject { tree[:second_tree].ns_parent.goods_nomenclature_item_id }

          let(:item_id) { "#{tree[:second_tree].goods_nomenclature_item_id.first(4)}000000" }

          it { is_expected.to eq item_id }
        end
      end

      describe '#ns_descendants' do
        it_behaves_like 'it has descendants', 'chapter', :chapter, %i[heading subheading subsubheading commodity1 commodity2 commodity3]
        it_behaves_like 'it has descendants', 'heading', :heading, %i[subheading subsubheading commodity1 commodity2 commodity3]
        it_behaves_like 'it has descendants', 'subheading', :subheading, %i[subsubheading commodity1 commodity2 commodity3]
        it_behaves_like 'it has descendants', 'nested subheading', :subsubheading, %i[commodity1 commodity2]
        it_behaves_like 'it has descendants', 'leaf commodity', :commodity1, %i[]
        it_behaves_like 'it has descendants', 'second leaf commodity', :commodity3, %i[]

        context 'for second tree' do
          subject { tree[:second_tree].ns_descendants.map(&:goods_nomenclature_item_id) }

          it { is_expected.to have_attributes length: 3 }
        end
      end

      describe 'with time machine' do
        before do
          create :goods_nomenclature_indent,
                 goods_nomenclature: tree[:subsubheading],
                 validity_start_date: 1.week.ago.at_beginning_of_day,
                 number_indents: 1

          create :goods_nomenclature_indent,
                 goods_nomenclature: tree[:commodity1],
                 validity_start_date: 1.week.ago.at_beginning_of_day,
                 number_indents: 2

          create :goods_nomenclature_indent,
                 goods_nomenclature: tree[:commodity2],
                 validity_start_date: 1.week.ago.at_beginning_of_day,
                 number_indents: 2
        end

        describe '#ns_ancestors' do
          it_behaves_like 'it has ancestors', 'subsubheading', :subsubheading, %i[chapter heading]
          it_behaves_like 'it has ancestors', 'commodity under subsubheading', :commodity1, %i[chapter heading subsubheading]
          it_behaves_like 'it has ancestors', 'commodity under subheading', :commodity3, %i[chapter heading subsubheading]
        end

        describe '#ns_parent' do
          it_behaves_like 'it has parent', 'subsubheading', :subsubheading, :heading
          it_behaves_like 'it has parent', 'commodity under subsubheading', :commodity1, :subsubheading
          it_behaves_like 'it has parent', 'commodity under subheading', :commodity3, :subsubheading
        end

        describe '#ns_descendants' do
          it_behaves_like 'it has descendants', 'heading', :heading, %i[subheading subsubheading commodity1 commodity2 commodity3]
          it_behaves_like 'it has descendants', 'subheading', :subheading, %i[]
          it_behaves_like 'it has descendants', 'nested subheading', :subsubheading, %i[commodity1 commodity2 commodity3]
        end

        context 'when accessing historical data via TimeMachine' do
          around { |example| TimeMachine.at(2.weeks.ago) { example.run } }

          describe '#ns_ancestors' do
            it_behaves_like 'it has ancestors', 'nested subheading', :subsubheading, %i[chapter heading subheading]
            it_behaves_like 'it has ancestors', 'leaf commodity', :commodity1, %i[chapter heading subheading subsubheading]
            it_behaves_like 'it has ancestors', 'second leaf commodity', :commodity3, %i[chapter heading subheading]
          end

          describe '#ns_parent' do
            it_behaves_like 'it has parent', 'nested subheading', :subsubheading, :subheading
            it_behaves_like 'it has parent', 'leaf commodity', :commodity1, :subsubheading
            it_behaves_like 'it has parent', 'second leaf commodity', :commodity3, :subheading
          end

          describe '#ns_descendants' do
            it_behaves_like 'it has descendants', 'heading', :heading, %i[subheading subsubheading commodity1 commodity2 commodity3]
            it_behaves_like 'it has descendants', 'subheading', :subheading, %i[subsubheading commodity1 commodity2 commodity3]
            it_behaves_like 'it has descendants', 'nested subheading', :subsubheading, %i[commodity1 commodity2]
          end
        end
      end
    end
  end
end
