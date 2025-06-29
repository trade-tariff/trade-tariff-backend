RSpec.describe GoodsNomenclatures::NestedSet do
  before do
    TradeTariffRequest.time_machine_now = Time.current
  end

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
      it { is_expected.to have_attributes number_indents: 1 }
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
          before do
            TradeTariffRequest.time_machine_now = 2.weeks.ago
          end

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
        subheading = create(:subheading, parent: heading)
        subsubheading = create(:subheading, parent: subheading)
        commodity1 = create(:commodity, parent: subsubheading)
        commodity2 = create(:commodity, parent: subsubheading)
        commodity3 = create(:commodity, parent: subheading)
        second_tree = create(:subheading, :with_chapter_and_heading, :with_children)

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
          subject { tree[node].ancestors }

          it { is_expected.to eq_pk tree.values_at(*ancestors) }
        end
      end

      shared_examples 'it has parent' do |context_name, node, parent_node|
        context "with #{context_name}" do
          subject { tree[node].parent }

          it { is_expected.to eq_pk tree[parent_node] }
        end
      end

      shared_examples 'it has descendants' do |context_name, node, descendants|
        context "with #{context_name}" do
          subject { tree[node].descendants }

          it { is_expected.to eq_pk tree.values_at(*descendants) }
        end
      end

      shared_examples 'it has children' do |context_name, node, children|
        context "with #{context_name}" do
          subject { tree[node].children }

          it { is_expected.to eq_pk tree.values_at(*children) }
        end
      end

      shared_examples 'it supports eager loading' do |relationship|
        subject do
          commodities.eager(:tree_node, relationship).all.first.associations[relationship]
        end

        let :commodities do
          GoodsNomenclature.where(goods_nomenclature_sid: tree[:subsubheading].goods_nomenclature_sid)
        end

        it { is_expected.not_to be_nil }
      end

      describe '#ancestors' do
        let(:third_tier_ancestors) { tree.values_at(:chapter, :heading, :subheading) }

        it_behaves_like 'it has ancestors', 'chapter', :chapter, []
        it_behaves_like 'it has ancestors', 'heading', :heading, %i[chapter]
        it_behaves_like 'it has ancestors', 'subheading', :subheading, %i[chapter heading]
        it_behaves_like 'it has ancestors', 'nested subheading', :subsubheading, %i[chapter heading subheading]
        it_behaves_like 'it has ancestors', 'leaf commodity', :commodity1, %i[chapter heading subheading subsubheading]
        it_behaves_like 'it has ancestors', 'second leaf commodity', :commodity3, %i[chapter heading subheading]

        it_behaves_like 'it supports eager loading', :ancestors

        context 'for second tree' do
          subject { tree[:second_tree].ancestors.map(&:goods_nomenclature_item_id) }

          let(:commodity) { tree[:second_tree] }

          let(:expected_ancestor_item_ids) do
            [
              "#{commodity.goods_nomenclature_item_id.first(2)}00000000",
              "#{commodity.goods_nomenclature_item_id.first(4)}000000",
            ]
          end

          it { is_expected.to eq expected_ancestor_item_ids }
        end

        context 'when eager loading' do
          let(:eager_loaded) { commodities.eager(:ancestors).all.first }

          let :commodities do
            GoodsNomenclature.where(goods_nomenclature_sid: tree[:subsubheading].goods_nomenclature_sid)
          end

          context 'for eager loaded goods nomenclature' do
            subject { eager_loaded.associations[:parent] }

            it { is_expected.to eq_pk tree[:subheading] }
          end

          context 'for eager loaded goods nomenclatures parents parent' do
            subject { eager_loaded.associations[:parent].associations[:parent] }

            it { is_expected.to eq_pk tree[:heading] }
          end

          context 'for eager loaded goods nomenclatures parents ancestors' do
            subject { eager_loaded.associations[:parent].associations[:ancestors] }

            it { is_expected.to eq_pk tree.values_at(:chapter, :heading) }
          end
        end

        describe 'values from db query' do
          subject { tree[:subheading].ancestors.map(&:values) }

          it { is_expected.to all include leaf: false }
          it { is_expected.to all include :number_indents }
        end
      end

      describe '#parent' do
        it_behaves_like 'it has parent', 'chapter', :chapter, nil
        it_behaves_like 'it has parent', 'heading', :heading, :chapter
        it_behaves_like 'it has parent', 'subheading', :subheading, :heading
        it_behaves_like 'it has parent', 'nested heading', :subsubheading, :subheading
        it_behaves_like 'it has parent', 'leaf commodity', :commodity1, :subsubheading
        it_behaves_like 'it has parent', 'second leaf commodity', :commodity3, :subheading

        it_behaves_like 'it supports eager loading', :parent

        context 'for second tree' do
          subject { tree[:second_tree].parent.goods_nomenclature_item_id }

          let(:item_id) { "#{tree[:second_tree].goods_nomenclature_item_id.first(4)}000000" }

          it { is_expected.to eq item_id }
        end

        describe 'values from db query' do
          subject { tree[:subheading].parent.values }

          it { is_expected.to include leaf: false }
          it { is_expected.to include number_indents: 0 }
        end
      end

      describe '#descendants' do
        it_behaves_like 'it has descendants', 'chapter', :chapter, %i[heading subheading subsubheading commodity1 commodity2 commodity3]
        it_behaves_like 'it has descendants', 'heading', :heading, %i[subheading subsubheading commodity1 commodity2 commodity3]
        it_behaves_like 'it has descendants', 'subheading', :subheading, %i[subsubheading commodity1 commodity2 commodity3]
        it_behaves_like 'it has descendants', 'nested subheading', :subsubheading, %i[commodity1 commodity2]
        it_behaves_like 'it has descendants', 'leaf commodity', :commodity1, %i[]
        it_behaves_like 'it has descendants', 'second leaf commodity', :commodity3, %i[]

        it_behaves_like 'it supports eager loading', :descendants

        context 'for second tree' do
          subject { tree[:second_tree].descendants.map(&:goods_nomenclature_item_id) }

          it { is_expected.to have_attributes length: 3 }
        end

        context 'with hidden_goods_nomenclatures' do
          before do
            create :hidden_goods_nomenclature,
                   goods_nomenclature_item_id: tree[:commodity2].goods_nomenclature_item_id
          end

          it_behaves_like 'it has descendants', 'nested subheading', :subsubheading, %i[commodity1]
        end

        context 'when eager loading' do
          let(:eager_loaded) { commodities.eager(:descendants).all.first }

          let :commodities do
            GoodsNomenclature.where(goods_nomenclature_sid: tree[:subheading].goods_nomenclature_sid)
          end

          context 'for eager loaded goods nomenclatures children' do
            subject { eager_loaded.associations[:children] }

            it { is_expected.to eq_pk [tree[:subsubheading], tree[:commodity3]] }
          end

          context 'for eager loaded goods_nomenclatures childs descendants' do
            subject { eager_loaded.associations[:children].first.associations[:descendants] }

            it { is_expected.to eq_pk tree.values_at(:commodity1, :commodity2) }
          end

          context 'for eager loaded goods nomenclatures childs children' do
            subject { eager_loaded.associations[:children].first.associations[:children] }

            it { is_expected.to eq_pk [tree[:commodity1], tree[:commodity2]] }
          end

          context 'for eager loaded goods nomenclatures childs parent' do
            subject { eager_loaded.associations[:children].first.associations[:parent] }

            it { is_expected.to eq_pk tree[:subheading] }
          end

          context 'for eager loaded goods nomenclatures childs childrens parent' do
            subject do
              eager_loaded.associations[:children]
                          .first
                          .associations[:children]
                          .first
                          .associations[:parent]
            end

            it { is_expected.to eq_pk tree[:subsubheading] }
          end

          context 'when including ancestors' do
            let(:eager_loaded) do
              commodities.eager(:ancestors, :descendants).all.first
            end

            context 'for eager loaded goods nomenclatures childs childrens parent' do
              subject(:leaf) do
                eager_loaded.associations[:children]
                            .first
                            .associations[:children]
                            .first
                            .associations[:ancestors]
              end

              it 'populates descendant ancestors automatically' do
                expect(leaf).to eq_pk tree.values_at(:chapter,
                                                     :heading,
                                                     :subheading,
                                                     :subsubheading)
              end
            end
          end
        end

        describe 'values from db query' do
          subject { tree[:subheading].descendants[0].values }

          it { is_expected.to include number_indents: 2 }
        end
      end

      describe '#children' do
        it_behaves_like 'it has children', 'chapter', :chapter, %i[heading]
        it_behaves_like 'it has children', 'heading', :heading, %i[subheading]
        it_behaves_like 'it has children', 'subheading', :subheading, %i[subsubheading commodity3]
        it_behaves_like 'it has children', 'nested subheading', :subsubheading, %i[commodity1 commodity2]
        it_behaves_like 'it has children', 'leaf commodity', :commodity1, %i[]
        it_behaves_like 'it has children', 'second leaf commodity', :commodity3, %i[]

        it_behaves_like 'it supports eager loading', :children

        context 'for second tree' do
          subject { tree[:second_tree].children.map(&:goods_nomenclature_item_id) }

          it { is_expected.to have_attributes length: 1 }
        end

        context 'with hidden_goods_nomenclatures' do
          before do
            create :hidden_goods_nomenclature,
                   goods_nomenclature_item_id: tree[:commodity3].goods_nomenclature_item_id
          end

          it_behaves_like 'it has children', 'subheading', :subheading, %i[subsubheading]
        end

        describe 'values from db query' do
          subject { tree[:subheading].children[0].values }

          it { is_expected.to include number_indents: 2 }
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
          it_behaves_like 'it has ancestors', 'subsubheading', :subsubheading, %i[chapter heading]
          it_behaves_like 'it has ancestors', 'commodity under subsubheading', :commodity1, %i[chapter heading subsubheading]
          it_behaves_like 'it has ancestors', 'commodity under subheading', :commodity3, %i[chapter heading subsubheading]
        end

        describe '#parent' do
          it_behaves_like 'it has parent', 'subsubheading', :subsubheading, :heading
          it_behaves_like 'it has parent', 'commodity under subsubheading', :commodity1, :subsubheading
          it_behaves_like 'it has parent', 'commodity under subheading', :commodity3, :subsubheading
        end

        describe '#descendants' do
          it_behaves_like 'it has descendants', 'heading', :heading, %i[subheading subsubheading commodity1 commodity2 commodity3]
          it_behaves_like 'it has descendants', 'subheading', :subheading, %i[]
          it_behaves_like 'it has descendants', 'nested subheading', :subsubheading, %i[commodity1 commodity2 commodity3]
        end

        describe '#children' do
          it_behaves_like 'it has children', 'heading', :heading, %i[subheading subsubheading]
          it_behaves_like 'it has children', 'subheading', :subheading, %i[]
          it_behaves_like 'it has children', 'nested subheading', :subsubheading, %i[commodity1 commodity2 commodity3]
        end

        context 'when accessing historical data via TimeMachine' do
          before do
            TradeTariffRequest.time_machine_now = 2.weeks.ago
          end

          around { |example| TimeMachine.at(2.weeks.ago) { example.run } }

          describe '#ancestors' do
            it_behaves_like 'it has ancestors', 'nested subheading', :subsubheading, %i[chapter heading subheading]
            it_behaves_like 'it has ancestors', 'leaf commodity', :commodity1, %i[chapter heading subheading subsubheading]
            it_behaves_like 'it has ancestors', 'second leaf commodity', :commodity3, %i[chapter heading subheading]
          end

          describe '#parent' do
            it_behaves_like 'it has parent', 'nested subheading', :subsubheading, :subheading
            it_behaves_like 'it has parent', 'leaf commodity', :commodity1, :subsubheading
            it_behaves_like 'it has parent', 'second leaf commodity', :commodity3, :subheading
          end

          describe '#descendants' do
            it_behaves_like 'it has descendants', 'heading', :heading, %i[subheading subsubheading commodity1 commodity2 commodity3]
            it_behaves_like 'it has descendants', 'subheading', :subheading, %i[subsubheading commodity1 commodity2 commodity3]
            it_behaves_like 'it has descendants', 'nested subheading', :subsubheading, %i[commodity1 commodity2]
          end

          describe '#children' do
            it_behaves_like 'it has children', 'heading', :heading, %i[subheading]
            it_behaves_like 'it has children', 'subheading', :subheading, %i[subsubheading commodity3]
            it_behaves_like 'it has children', 'nested subheading', :subsubheading, %i[commodity1 commodity2]
          end
        end

        context 'when outside of TimeMachine' do
          before do
            TradeTariffRequest.time_machine_now = nil
          end

          around { |example| TimeMachine.no_time_machine { example.run } }

          let(:commodity) { create :commodity }

          describe '#ancestors' do
            it { expect { commodity.ancestors }.to raise_exception described_class::DateNotSet }
          end

          describe '#parent' do
            it { expect { commodity.parent }.to raise_exception described_class::DateNotSet }
          end

          describe '#children' do
            it { expect { commodity.children }.to raise_exception described_class::DateNotSet }
          end

          describe '#descendants' do
            it { expect { commodity.descendants }.to raise_exception described_class::DateNotSet }
          end
        end
      end
    end

    describe '#measures' do
      subject { measure.goods_nomenclature.measures.map(&:measure_sid) }

      let :measure do
        create :measure, :with_base_regulation, :with_goods_nomenclature, measure_type_id:
      end

      let(:measure_type_id) { MeasureType::QUOTA_TYPES.first }

      it { is_expected.to include measure.measure_sid }

      context 'with measures that are excluded' do
        let(:measure_type_id) { MeasureType::DEFAULT_EXCLUDED_TYPES.first }

        it { is_expected.not_to include measure.measure_sid }
      end

      context 'with eager loading' do
        subject do
          GoodsNomenclature
            .actual
            .where(goods_nomenclature_sid: measure.goods_nomenclature_sid)
            .eager(:measures)
            .all
            .first
            .associations[:measures]
            .map(&:measure_sid)
        end

        it { is_expected.to include measure.measure_sid }
      end
    end

    describe '#overview_measures' do
      subject { measure.goods_nomenclature.overview_measures.map(&:measure_sid) }

      let :measure do
        create :measure, :with_base_regulation, :with_goods_nomenclature, measure_type_id:
      end

      let(:measure_type_id) { MeasureType::SUPPLEMENTARY_TYPES.first }

      it { is_expected.to include measure.measure_sid }

      context 'with non overview measure types' do
        let(:measure_type_id) { MeasureType::QUOTA_TYPES.first }

        it { is_expected.not_to include measure.measure_sid }
      end

      context 'with measures that are excluded' do
        let(:measure_type_id) { MeasureType::DEFAULT_EXCLUDED_TYPES.first }

        it { is_expected.not_to include measure.measure_sid }
      end

      context 'with eager loading' do
        subject do
          GoodsNomenclature
            .actual
            .where(goods_nomenclature_sid: measure.goods_nomenclature_sid)
            .eager(:overview_measures)
            .all
            .first
            .associations[:overview_measures]
            .map(&:measure_sid)
        end

        it { is_expected.to include measure.measure_sid }
      end
    end
  end

  describe '.with_leaf_column' do
    subject do
      GoodsNomenclature.with_leaf_column
                       .all
                       .index_by(&:goods_nomenclature_sid)
                       .transform_values(&:leaf)
    end

    before { commodity }

    let(:subheading) { create :subheading, :with_chapter_and_heading }
    let(:commodity) { create :commodity, parent: subheading }

    it { is_expected.to include subheading.chapter.pk => false }
    it { is_expected.to include subheading.pk => false }
    it { is_expected.to include commodity.pk => true }
  end

  describe '.declarable' do
    subject { GoodsNomenclature.actual.declarable.all }

    before { commodity }

    let(:commodity) { create :commodity, :non_grouping, :with_children }

    it { is_expected.not_to include commodity }
    it { is_expected.to include commodity.children.first.children.first }
  end

  describe '#declarable?' do
    context 'with descendants' do
      subject { create :commodity, :non_grouping, :with_children }

      it { is_expected.not_to be_declarable }
    end

    context 'without descendants' do
      subject { create :commodity, :non_grouping, :without_children }

      it { is_expected.to be_declarable }
    end

    context 'with grouping productline suffix' do
      subject { create :commodity, :grouping, :without_children }

      it { is_expected.not_to be_declarable }
    end
  end

  describe '#number_indents' do
    subject { gn.number_indents }

    let(:commodity) { create :commodity, :with_chapter_and_heading }

    context 'with goods_nomenclature_indents' do
      let(:gn) { commodity }

      it { is_expected.to be 1 }
    end

    context 'with tree nodes' do
      before do
        allow(gn.goods_nomenclature_indent).to receive(:number_indents).and_return 200
      end

      context 'with chapter' do
        let(:gn) { commodity.ancestors[0] }

        it { is_expected.to be 0 }
      end

      context 'with heading' do
        let(:gn) { commodity.ancestors[1] }

        it { is_expected.to be 0 }
      end

      context 'with commodity' do
        let(:gn) { commodity.parent.descendants[0] }

        it { is_expected.to be 1 }
      end
    end
  end

  describe '#applicable_measures' do
    subject(:applied_measures) { measure.goods_nomenclature.applicable_measures }

    let(:subheading) { create :commodity, :with_chapter_and_heading, :with_children }

    let :measure do
      create :measure,
             :with_base_regulation,
             geographical_area_id: 'ES',
             measure_type_id: 2,
             goods_nomenclature: subheading.children.first
    end

    it { is_expected.to eq_pk [measure] }

    context 'with measures against ancestors' do
      before { ancestor_measure && parent_measure }

      let :ancestor_measure do
        create :measure,
               :with_base_regulation,
               geographical_area_id: 'FR',
               goods_nomenclature: subheading.parent
      end

      let :parent_measure do
        create :measure,
               :with_base_regulation,
               geographical_area_id: 'ES',
               measure_type_id: 4,
               goods_nomenclature: subheading
      end

      it 'has correct and sorted measures' do
        expect(applied_measures).to eq_pk [measure, parent_measure, ancestor_measure]
      end
    end
  end

  describe '#applicable_overview_measures' do
    subject(:applied_measures) { measure.goods_nomenclature.applicable_overview_measures }

    let(:subheading) { create :commodity, :with_chapter_and_heading, :with_children }

    let :measure do
      create :measure,
             :supplementary,
             :with_base_regulation,
             :areas_subject_to_vat_or_excise,
             goods_nomenclature: subheading.children.first
    end

    it { is_expected.to eq_pk [measure] }

    context 'with measures against ancestors' do
      before { ancestor_measure && parent_measure }

      let :ancestor_measure do
        create :measure,
               :vat,
               :with_base_regulation,
               :areas_subject_to_vat_or_excise,
               goods_nomenclature: subheading.parent
      end

      let :parent_measure do
        create :measure,
               :tariff_preference,
               :with_base_regulation,
               :areas_subject_to_vat_or_excise,
               goods_nomenclature: subheading
      end

      it 'has correct and sorted measures' do
        expect(applied_measures).to eq_pk [measure, ancestor_measure]
      end
    end
  end
end
