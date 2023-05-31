RSpec.describe GoodsNomenclature do
  describe '#full_chemicals' do
    subject(:full_chemicals) { create(:goods_nomenclature, :with_full_chemicals).full_chemicals }

    it { is_expected.to all(be_a(FullChemical)) }
  end

  describe 'ordering', flaky: true do
    subject(:goods_nomenclatures) { described_class.all.pluck(:goods_nomenclature_item_id, :producline_suffix) }

    before do
      create(:commodity, producline_suffix: '80', goods_nomenclature_item_id: '0101210000')
      create(:heading, producline_suffix: '80', goods_nomenclature_item_id: '0102000000')
      create(:chapter, producline_suffix: '80', goods_nomenclature_item_id: '0100000000')
      create(:heading, producline_suffix: '80', goods_nomenclature_item_id: '0101000000')
      create(:commodity, producline_suffix: '10', goods_nomenclature_item_id: '0101210000')
    end

    let(:expected_goods_nomenclatures) do
      [
        %w[0100000000 80],
        %w[0101000000 80],
        %w[0101210000 10], # Included producline suffix in composite ordering
        %w[0101210000 80],
        %w[0102000000 80],
      ]
    end

    it { expect(goods_nomenclatures).to eq(expected_goods_nomenclatures) }
  end

  describe 'single table inheritance loader' do
    shared_examples 'it loads data into the correct class' do |klass, *traits|
      subject do
        described_class.where(goods_nomenclature_sid: gn.goods_nomenclature_sid)
                       .first
      end

      let(:gn) { create(:goods_nomenclature, *traits) }

      it { is_expected.to be_instance_of klass }
    end

    it_behaves_like 'it loads data into the correct class', Chapter, :chapter
    it_behaves_like 'it loads data into the correct class', Heading, :heading
    it_behaves_like 'it loads data into the correct class', Commodity, :with_children
    it_behaves_like 'it loads data into the correct class', Commodity
  end

  describe 'associations' do
    describe 'goods nomenclature indent' do
      context 'when fetching with absolute date' do
        before do
          create :goods_nomenclature_indent,
                 goods_nomenclature_sid: goods_nomenclature.goods_nomenclature_sid,
                 validity_start_date: 6.years.ago,
                 validity_end_date: 3.years.ago
        end

        let!(:goods_nomenclature) { create :goods_nomenclature, :without_indent }

        let!(:goods_nomenclature_indent1) do
          create :goods_nomenclature_indent,
                 goods_nomenclature_sid: goods_nomenclature.goods_nomenclature_sid,
                 validity_start_date: 2.years.ago,
                 validity_end_date: nil
        end

        let!(:goods_nomenclature_indent3) do
          create :goods_nomenclature_indent,
                 goods_nomenclature_sid: goods_nomenclature.goods_nomenclature_sid,
                 validity_start_date: 5.years.ago,
                 validity_end_date: 3.years.ago
        end

        context 'when loading without eager' do
          it 'loads correct indent respecting given actual time' do
            TimeMachine.now do
              expect(
                goods_nomenclature.goods_nomenclature_indent.pk,
              ).to eq goods_nomenclature_indent1.pk
            end
          end

          it 'loads correct indent respecting given time' do
            TimeMachine.at(4.years.ago) do
              expect(
                goods_nomenclature.reload.goods_nomenclature_indent.pk,
              ).to eq goods_nomenclature_indent3.pk
            end
          end
        end

        context 'when eager loading' do
          it 'loads correct indent respecting given actual time' do
            TimeMachine.now do
              expect(
                described_class.where(goods_nomenclature_sid: goods_nomenclature.goods_nomenclature_sid)
                            .eager(:goods_nomenclature_indents)
                            .all
                            .first
                            .goods_nomenclature_indent.pk,
              ).to eq goods_nomenclature_indent1.pk
            end
          end

          it 'loads correct indent respecting given time' do
            TimeMachine.at(4.years.ago) do
              expect(
                described_class.where(goods_nomenclature_sid: goods_nomenclature.goods_nomenclature_sid)
                            .eager(:goods_nomenclature_indents)
                            .all
                            .first
                            .goods_nomenclature_indent.pk,
              ).to eq goods_nomenclature_indent3.pk
            end
          end
        end
      end
    end

    describe 'goods nomenclature description' do
      context 'when fetching with absolute date' do
        context 'when at least one end date present' do
          let!(:goods_nomenclature)                { create :goods_nomenclature }
          let!(:goods_nomenclature_description1)   do
            create :goods_nomenclature_description,
                   goods_nomenclature_sid: goods_nomenclature.goods_nomenclature_sid,
                   validity_start_date: 2.years.ago,
                   validity_end_date: nil
          end
          let!(:goods_nomenclature_description2) do
            create :goods_nomenclature_description,
                   goods_nomenclature_sid: goods_nomenclature.goods_nomenclature_sid,
                   validity_start_date: 5.years.ago,
                   validity_end_date: 3.years.ago
          end

          context 'when loading without eager' do
            it 'loads correct description respecting given actual time' do
              TimeMachine.now do
                expect(
                  goods_nomenclature.goods_nomenclature_description.pk,
                ).to eq goods_nomenclature_description1.pk
              end
            end

            it 'loads correct description respecting given time' do
              TimeMachine.at(4.years.ago) do
                expect(
                  goods_nomenclature.reload.goods_nomenclature_description.pk,
                ).to eq goods_nomenclature_description2.pk
              end
            end
          end

          context 'when eager loading' do
            it 'loads correct description respecting given actual time' do
              TimeMachine.now do
                expect(
                  described_class.where(goods_nomenclature_sid: goods_nomenclature.goods_nomenclature_sid)
                              .eager(:goods_nomenclature_descriptions)
                              .all
                              .first
                              .goods_nomenclature_description.pk,
                ).to eq goods_nomenclature_description1.pk
              end
            end

            it 'loads correct description respecting given time' do
              TimeMachine.at(4.years.ago) do
                expect(
                  described_class.where(goods_nomenclature_sid: goods_nomenclature.goods_nomenclature_sid)
                              .eager(:goods_nomenclature_descriptions)
                              .all
                              .first
                              .goods_nomenclature_description.pk,
                ).to eq goods_nomenclature_description2.pk
              end
            end
          end
        end

        context 'when end dates are blank' do
          let!(:goods_nomenclature)                { create :goods_nomenclature }
          let!(:goods_nomenclature_description1)   do
            create :goods_nomenclature_description,
                   goods_nomenclature_sid: goods_nomenclature.goods_nomenclature_sid,
                   validity_start_date: 3.years.ago,
                   validity_end_date: nil
          end
          let!(:goods_nomenclature_description2) do
            create :goods_nomenclature_description,
                   goods_nomenclature_sid: goods_nomenclature.goods_nomenclature_sid,
                   validity_start_date: 5.years.ago,
                   validity_end_date: nil
          end

          context 'when loading without eager' do
            it 'loads correct description respecting given actual time' do
              TimeMachine.now do
                expect(
                  goods_nomenclature.goods_nomenclature_description.pk,
                ).to eq goods_nomenclature_description1.pk
              end
            end

            it 'loads correct description respecting given time' do
              TimeMachine.at(4.years.ago) do
                expect(
                  goods_nomenclature.reload.goods_nomenclature_description.pk,
                ).to eq goods_nomenclature_description2.pk
              end
            end
          end

          context 'when eager loading' do
            it 'loads correct description respecting given actual time' do
              TimeMachine.now do
                expect(
                  described_class.where(goods_nomenclature_sid: goods_nomenclature.goods_nomenclature_sid)
                              .eager(:goods_nomenclature_descriptions)
                              .all
                              .first
                              .goods_nomenclature_description.pk,
                ).to eq goods_nomenclature_description1.pk
              end
            end

            it 'loads correct description respecting given time' do
              TimeMachine.at(4.years.ago) do
                expect(
                  described_class.where(goods_nomenclature_sid: goods_nomenclature.goods_nomenclature_sid)
                              .eager(:goods_nomenclature_descriptions)
                              .all
                              .first
                              .goods_nomenclature_description.pk,
                ).to eq goods_nomenclature_description2.pk
              end
            end
          end
        end
      end

      context 'when fetching with relevant date' do
        before do
          create :goods_nomenclature_description,
                 goods_nomenclature_sid: goods_nomenclature.goods_nomenclature_sid,
                 validity_start_date: 5.years.ago,
                 validity_end_date: 3.years.ago
        end

        let!(:goods_nomenclature) do
          create :goods_nomenclature, validity_start_date: 1.year.ago,
                                      validity_end_date: nil
        end
        let!(:goods_nomenclature_description1) do
          create :goods_nomenclature_description,
                 goods_nomenclature_sid: goods_nomenclature.goods_nomenclature_sid,
                 validity_start_date: 2.years.ago,
                 validity_end_date: nil
        end

        it 'fetches correct description' do
          TimeMachine.with_relevant_validity_periods do
            expect(
              goods_nomenclature.goods_nomenclature_description.pk,
            ).to eq goods_nomenclature_description1.pk
          end
        end
      end
    end

    describe 'footnote' do
      let!(:goods_nomenclature) { create :goods_nomenclature }
      let!(:footnote1) do
        create :footnote, :with_gono_association,
               goods_nomenclature_sid: goods_nomenclature.goods_nomenclature_sid,
               valid_at: 2.years.ago,
               valid_to: nil
      end
      let!(:footnote2) do
        create :footnote, :with_gono_association,
               goods_nomenclature_sid: goods_nomenclature.goods_nomenclature_sid,
               valid_at: 5.years.ago,
               valid_to: 3.years.ago
      end

      context 'when loading without eager' do
        it 'loads correct indent respecting given actual time' do
          TimeMachine.now do
            expect(
              goods_nomenclature.footnote.pk,
            ).to eq footnote1.pk
          end
        end

        it 'loads correct indent respecting given time' do
          TimeMachine.at(4.years.ago) do
            expect(
              goods_nomenclature.reload.footnote.pk,
            ).to eq footnote2.pk
          end
        end
      end

      context 'when eager loading' do
        it 'loads correct indent respecting given actual time' do
          TimeMachine.now do
            expect(
              described_class.where(goods_nomenclature_sid: goods_nomenclature.goods_nomenclature_sid)
                          .eager(:footnotes)
                          .all
                          .first
                          .footnote.pk,
            ).to eq footnote1.pk
          end
        end

        it 'loads correct indent respecting given time' do
          TimeMachine.at(4.years.ago) do
            expect(
              described_class.where(goods_nomenclature_sid: goods_nomenclature.goods_nomenclature_sid)
                          .eager(:footnotes)
                          .all
                          .first
                          .footnote.pk,
            ).to eq footnote2.pk
          end
        end
      end
    end
  end

  describe '#code' do
    let(:gono) { create(:goods_nomenclature, goods_nomenclature_item_id: '8056116321') }

    it 'returns goods_nomenclature_item_id' do
      expect(gono.code).to eq('8056116321')
    end
  end

  describe '#bti_url' do
    let(:bti_url) do
      'https://www.gov.uk/guidance/check-what-youll-need-to-get-a-legally-binding-decision-on-a-commodity-code'
    end

    let(:gono) { create(:goods_nomenclature) }

    it 'includes gono code' do
      expect(gono.bti_url).to include(bti_url)
    end
  end

  describe '#chapter_id' do
    let(:gono) { create(:goods_nomenclature, goods_nomenclature_item_id: '8056116321') }

    it 'includes first to chars' do
      expect(gono.chapter_id).to include(gono.goods_nomenclature_item_id.first(2))
    end

    it 'includes eight 0' do
      expect(gono.chapter_id).to include('0' * 8)
    end
  end

  describe '#chapter_code' do
    subject(:chapter_code) { create(:goods_nomenclature, goods_nomenclature_item_id: '0101210000').chapter_code }

    it { is_expected.to eq('0100000000') }
  end

  describe '#heading_code' do
    subject(:heading_code) { create(:goods_nomenclature, goods_nomenclature_item_id: '0101210000').heading_code }

    it { is_expected.to eq('0101000000') }
  end

  describe '#to_s' do
    let(:gono) { create(:commodity, goods_nomenclature_item_id: '8056116321', indents: 4) }

    it 'includes number_indents' do
      expect(gono.to_s).to include(gono.number_indents.to_s)
    end

    it 'includes goods_nomenclature_item_id' do
      expect(gono.to_s).to include(gono.goods_nomenclature_item_id)
    end
  end

  describe '#goods_nomenclature_class' do
    context 'when the GoodsNomenclature is a Commodity' do
      subject(:goods_nomenclature_class) { create(:commodity, :declarable, :with_heading).goods_nomenclature_class }

      it { is_expected.to eq('Commodity') }
    end

    context 'when the GoodsNomenclature is a Subheading' do
      subject(:goods_nomenclature_class) { create(:commodity, :non_declarable, :with_heading).goods_nomenclature_class }

      it { is_expected.to eq('Subheading') }
    end

    context 'when the GoodsNomenclature is a Heading' do
      subject(:goods_nomenclature_class) { create(:heading).goods_nomenclature_class }

      it { is_expected.to eq('Heading') }
    end

    context 'when the GoodsNomenclature is a Chapter' do
      subject(:goods_nomenclature_class) { create(:chapter).goods_nomenclature_class }

      it { is_expected.to eq('Chapter') }
    end
  end

  describe '#chapter' do
    before do
      create(:chapter, goods_nomenclature_item_id: '0100000000')
    end

    context 'when the goods nomenclature is a chapter' do
      subject(:chapter) { create(:chapter, goods_nomenclature_item_id: '0100000000') }

      it { is_expected.to be_a(Chapter) }
    end

    context 'when the goods nomenclature is a heading' do
      subject(:chapter) { create(:heading, goods_nomenclature_item_id: '0101000000').chapter }

      it { is_expected.to be_a(Chapter) }
    end

    context 'when the goods nomenclature is a commodity' do
      subject(:chapter) { create(:commodity, goods_nomenclature_item_id: '0111110000').chapter }

      it { is_expected.to be_a(Chapter) }
    end
  end

  describe '#path_ancestors' do
    context 'when the goods nomenclature has ancestors' do
      subject(:ancestors) { create(:goods_nomenclature, :with_ancestors).path_ancestors }

      it { expect(ancestors).to include(an_instance_of(Chapter)) }
      it { expect(ancestors).to include(an_instance_of(Heading)) }
    end

    context 'when the goods nomenclature has no ancestors' do
      subject(:ancestors) { create(:goods_nomenclature, :without_ancestors).path_ancestors }

      it { expect(ancestors).to be_empty }
    end
  end

  describe '#path_parent' do
    context 'when the goods nomenclature has an immediate parent' do
      subject(:parent) { create(:goods_nomenclature, :with_parent).path_parent }

      it { expect(parent).to be_a(described_class) }
    end

    context 'when the goods nomenclature has no parent' do
      subject(:parent) { create(:goods_nomenclature, :without_parent).path_parent }

      it { expect(parent).to be_nil }
    end
  end

  describe '#path_siblings' do
    context 'when the goods nomenclature has siblings' do
      subject(:siblings) { create(:goods_nomenclature, :with_siblings).path_siblings }

      it { expect(siblings).to include(an_instance_of(Commodity)) }
    end

    context 'when the goods nomenclature has no siblings' do
      subject(:siblings) { create(:goods_nomenclature, :without_siblings).path_siblings }

      it { expect(siblings).to be_empty }
    end
  end

  describe '#path_children' do
    context 'when the goods nomenclature has children' do
      subject(:child_sids) { create(:goods_nomenclature, :with_children).path_children.count }

      it { is_expected.to eq(1) }
    end

    context 'when the goods nomenclature has no children' do
      subject(:child_sids) { create(:goods_nomenclature, :without_children).path_children.map(&:goods_nomenclature_sid) }

      it { is_expected.to be_empty }
    end
  end

  describe '#path_descendants' do
    context 'when the goods nomenclature has descendants' do
      subject(:descendant_sids) { create(:goods_nomenclature, :with_descendants).path_descendants.length }

      it { is_expected.to eq(2) }
    end

    context 'when the goods nomenclature has no descendants' do
      subject(:descendant_sids) { create(:goods_nomenclature, :without_descendants).path_descendants.length }

      it { is_expected.to be_zero }
    end
  end

  describe '#heading?' do
    context 'when the goods nomenclature has a heading goods nomenclature item id' do
      subject(:goods_nomenclature) { create(:goods_nomenclature, :heading) }

      it { is_expected.to be_heading }
    end

    context 'when the goods nomenclature has a non-heading goods nomenclature item id' do
      subject(:goods_nomenclature) { create(:goods_nomenclature, :commodity) }

      it { is_expected.not_to be_heading }
    end
  end

  describe '#chapter?' do
    context 'when the goods nomenclature has a chapter goods nomenclature item id' do
      subject(:goods_nomenclature) { create(:goods_nomenclature, :chapter) }

      it { is_expected.to be_chapter }
    end

    context 'when the goods nomenclature has a non-chapter goods nomenclature item id' do
      subject(:goods_nomenclature) { create(:goods_nomenclature, :commodity) }

      it { is_expected.not_to be_chapter }
    end
  end

  describe '#path_declarable?' do
    context 'when the goods nomenclature has children and a non grouping suffix' do
      subject(:goods_nomenclature) { create(:goods_nomenclature, :with_children, :non_grouping) }

      it { is_expected.not_to be_path_declarable }
    end

    context 'when the goods nomenclature has children and a grouping suffix' do
      subject(:goods_nomenclature) { create(:goods_nomenclature, :with_children, :grouping) }

      it { is_expected.not_to be_path_declarable }
    end

    context 'when the goods nomenclature has no children and a non grouping suffix' do
      subject(:goods_nomenclature) { create(:goods_nomenclature, :without_children, :non_grouping) }

      it { is_expected.to be_path_declarable }
    end

    context 'when the goods nomenclature has no children and a grouping suffix' do
      subject(:goods_nomenclature) { create(:goods_nomenclature, :without_children, :grouping) }

      it { is_expected.not_to be_path_declarable }
    end
  end

  describe '#classifiable_goods_nomenclatures' do
    subject(:classifiable_goods_nomenclatures) do
      described_class
        .find(goods_nomenclature_sid: goods_nomenclature.goods_nomenclature_sid)
        .classifiable_goods_nomenclatures
        .pluck(:goods_nomenclature_sid)
    end

    context 'when there are ancestors for the current goods nomenclature' do
      let(:goods_nomenclature) { create(:commodity, :with_ancestors) }

      let(:gn_sids) { [goods_nomenclature.goods_nomenclature_sid, 2, 1] }

      it { expect(classifiable_goods_nomenclatures).to eq(gn_sids) }
    end

    context 'when there are no ancestors for the current goods nomenclature' do
      let(:goods_nomenclature) { create(:commodity) }

      let(:gn_sids) { [goods_nomenclature.goods_nomenclature_sid] }

      it { expect(classifiable_goods_nomenclatures).to eq(gn_sids) }
    end
  end

  describe '#goods_nomenclature_descriptions' do
    context 'when the description column is null' do
      subject(:goods_nomenclature_descriptions) do
        create(
          :goods_nomenclature,
          :with_description,
          description: nil,
        ).goods_nomenclature_descriptions
      end

      it { is_expected.to be_empty }
    end

    context 'when the description column is not null' do
      subject(:goods_nomenclature_descriptions) do
        create(
          :goods_nomenclature,
          :with_description,
          description: 'foo',
        ).goods_nomenclature_descriptions
      end

      it { is_expected.not_to be_empty }
    end
  end

  describe '#intercept_terms' do
    subject(:goods_nomenclature) { build(:goods_nomenclature, goods_nomenclature_item_id:) }

    context 'when there are intercept terms for the goods nomenclature' do
      let(:goods_nomenclature_item_id) { '9031800000' }

      it { expect(goods_nomenclature.intercept_terms).to eq('accelerometer bruel kjaer eddy current eddyfi ectane fitbit rotary encoder') }
    end

    context 'when there are `no` intercept terms for the goods nomenclature' do
      let(:goods_nomenclature_item_id) { '9031810000' }

      it { expect(goods_nomenclature.intercept_terms).to eq('') }
    end
  end

  describe '#to_admin_param' do
    subject { goods_nomenclature.to_admin_param }

    let(:goods_nomenclature) { create(:goods_nomenclature) }

    it { is_expected.to eq(goods_nomenclature.to_param) }
  end

  describe '#has_chemicals' do
    context 'when the goods nomenclature has no chemicals' do
      subject(:has_chemicals) { create(:goods_nomenclature).has_chemicals }

      it { is_expected.to be(false) }
    end

    context 'when the goods nomenclature has chemicals' do
      subject(:has_chemicals) { create(:goods_nomenclature, :with_full_chemicals).has_chemicals }

      it { is_expected.to be(true) }
    end
  end

  describe '#non_grouping?' do
    context 'when the commodity has a non-grouping producline_suffix' do
      subject(:commodity) { create(:commodity, :non_grouping) }

      it { is_expected.to be_non_grouping }
    end

    context 'when the commodity has a grouping producline_suffix' do
      subject(:commodity) { create(:commodity, :grouping) }

      it { is_expected.not_to be_non_grouping }
    end
  end

  describe '#grouping?' do
    context 'when the commodity has a grouping producline_suffix' do
      subject(:commodity) { create(:commodity, :grouping) }

      it { is_expected.to be_grouping }
    end

    context 'when the commodity has a non-grouping producline_suffix' do
      subject(:commodity) { create(:commodity, :non_grouping) }

      it { is_expected.not_to be_grouping }
    end
  end

  describe '#path_goods_nomenclature_class' do
    shared_examples 'a goods nomenclature class' do |goods_nomenclature_item_id, expected_class|
      subject(:goods_nomenclature_class) { described_class.find(goods_nomenclature_item_id:).path_goods_nomenclature_class }

      it { is_expected.to eq(expected_class) }
    end

    it_behaves_like 'a goods nomenclature class', '0100000000', 'Chapter' do
      before do
        create(:chapter, goods_nomenclature_item_id: '0100000000')
      end
    end

    it_behaves_like 'a goods nomenclature class', '0101000000', 'Heading' do
      before do
        create(:heading, goods_nomenclature_item_id: '0101000000')
      end
    end

    it_behaves_like 'a goods nomenclature class', '0101210001', 'Subheading' do
      before do
        create(:subheading, goods_nomenclature_item_id: '0101210001')
      end
    end

    it_behaves_like 'a goods nomenclature class', '0101210000', 'Commodity' do
      before do
        create(:commodity, goods_nomenclature_item_id: '0101210000')
      end
    end
  end

  describe '.non_classifieds' do
    subject(:non_classifieds) { described_class.non_classifieds.pluck(:goods_nomenclature_item_id) }

    before do
      create(:goods_nomenclature, :classified)
      create(:goods_nomenclature, goods_nomenclature_item_id: '0111110000')
    end

    it { is_expected.to eq(%w[0111110000]) }
  end
end
