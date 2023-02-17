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

      describe '#ns_ancestors' do
        let(:third_tier_ancestors) { tree.values_at(:chapter, :heading, :subheading) }

        context 'with chapter' do
          subject { tree[:chapter].ns_ancestors.map(&:goods_noemnclature_sid) }

          it { is_expected.to be_empty }
        end

        context 'with heading' do
          subject { tree[:heading].ns_ancestors.map(&:goods_nomenclature_sid) }

          it { is_expected.to eq [tree[:chapter].goods_nomenclature_sid] }
        end

        context 'with subheading' do
          subject { tree[:subheading].ns_ancestors.map(&:goods_nomenclature_sid) }

          it { is_expected.to eq tree.values_at(:chapter, :heading).map(&:goods_nomenclature_sid) }
        end

        context 'with nested subheading' do
          subject { tree[:subsubheading].ns_ancestors.map(&:goods_nomenclature_sid) }

          it { is_expected.to eq third_tier_ancestors.map(&:goods_nomenclature_sid) }
        end

        context 'for leaf commodity' do
          subject { tree[:commodity1].ns_ancestors.map(&:goods_nomenclature_sid) }

          let :ancestors do
            tree.values_at(:chapter, :heading, :subheading, :subsubheading)
          end

          it { is_expected.to eq ancestors.map(&:goods_nomenclature_sid) }
        end

        context 'for second leaf commodity' do
          subject { tree[:commodity3].ns_ancestors.map(&:goods_nomenclature_sid) }

          it { is_expected.to eq third_tier_ancestors.map(&:goods_nomenclature_sid) }
        end

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

        describe '#ancestors' do
          context 'with subsubheading' do
            subject { tree[:subsubheading].ns_ancestors.map(&:goods_nomenclature_sid) }

            it { is_expected.to eq tree.values_at(:chapter, :heading).map(&:goods_nomenclature_sid) }
          end

          context 'with commodity under subsubheading' do
            subject { tree[:commodity1].ns_ancestors.map(&:goods_nomenclature_sid) }

            it { is_expected.to eq tree.values_at(:chapter, :heading, :subsubheading).map(&:goods_nomenclature_sid) }
          end

          context 'with commodity under subheading' do
            subject { tree[:commodity3].ns_ancestors.map(&:goods_nomenclature_sid) }

            it { is_expected.to eq tree.values_at(:chapter, :heading, :subsubheading).map(&:goods_nomenclature_sid) }
          end
        end

        context 'when accessing historical data via TimeMachine' do
          around { |example| TimeMachine.at(2.weeks.ago) { example.run } }

          context 'with nested subheading' do
            subject { tree[:subsubheading].ns_ancestors.map(&:goods_nomenclature_sid) }

            it { is_expected.to eq tree.values_at(:chapter, :heading, :subheading).map(&:goods_nomenclature_sid) }
          end

          context 'for leaf commodity' do
            subject { tree[:commodity1].ns_ancestors.map(&:goods_nomenclature_sid) }

            let :ancestors do
              tree.values_at(:chapter, :heading, :subheading, :subsubheading)
            end

            it { is_expected.to eq ancestors.map(&:goods_nomenclature_sid) }
          end

          context 'for second leaf commodity' do
            subject { tree[:commodity3].ns_ancestors.map(&:goods_nomenclature_sid) }

            it { is_expected.to eq tree.values_at(:chapter, :heading, :subheading).map(&:goods_nomenclature_sid) }
          end
        end
      end
    end
  end
end
