RSpec.describe HeadingService::CachedHeadingService, flaky: true do
  let(:heading) do
    create(
      :heading,
      :non_grouping,
      :with_indent,
      :with_description,
    )
  end

  describe '#serializable_hash' do
    subject(:serializable_hash) { described_class.new(heading.reload, actual_date).serializable_hash }

    let(:actual_date) { Time.zone.today }

    context 'when footnotes, chapter, commodities and overview measures has valid period' do
      before do
        commodity = create(
          :goods_nomenclature,
          :with_description,
          :with_indent,
          goods_nomenclature_item_id: "#{heading.short_code}#{6.times.map { Random.rand(9) }.join}",
        )
        create(
          :footnote,
          :with_gono_association,
          :with_description,
          goods_nomenclature_sid: heading.goods_nomenclature_sid,
        )
        create(
          :chapter,
          :with_section, :with_description,
          goods_nomenclature_item_id: heading.chapter_id
        )
        create(
          :measure,
          :with_base_regulation,
          :third_country_overview,
          goods_nomenclature_sid: commodity.goods_nomenclature_sid,
        )
      end

      it { expect(serializable_hash.chapter).not_to be(nil) }
      it { expect(serializable_hash.chapter_id).not_to be(nil) }
      it { expect(serializable_hash.footnotes).not_to be_empty }
      it { expect(serializable_hash.commodities).not_to be_empty }
      it { expect(serializable_hash.commodities.first.overview_measures).not_to be_empty }
    end

    context 'when footnotes has not valid period' do
      before do
        create(
          :footnote,
          :with_description,
          :with_gono_association,
          validity_start_date: 1.week.ago.beginning_of_day,
          validity_end_date: Time.zone.yesterday,
          goods_nomenclature_sid: heading.goods_nomenclature_sid,
        )
        create(
          :chapter,
          :with_section,
          :with_description,
          goods_nomenclature_item_id: heading.chapter_id,
        )
        commodity = create(
          :goods_nomenclature,
          :with_description,
          :with_indent,
          goods_nomenclature_item_id: "#{heading.short_code}#{6.times.map { Random.rand(9) }.join}",
        )
        create(
          :measure,
          :with_base_regulation,
          :third_country_overview,
          goods_nomenclature_sid: commodity.goods_nomenclature_sid,
        )
      end

      it { expect(serializable_hash.footnotes).to be_empty }
    end

    context 'when chapter has not valid period' do
      before do
        create(
          :footnote,
          :with_gono_association,
          :with_description,
          goods_nomenclature_sid: heading.goods_nomenclature_sid,
        )
        create(
          :chapter,
          :with_section,
          :with_description,
          validity_start_date: 1.week.ago.beginning_of_day,
          validity_end_date: Time.zone.yesterday,
          goods_nomenclature_item_id: heading.chapter_id,
        )
        commodity = create(
          :goods_nomenclature,
          :with_description,
          :with_indent,
          goods_nomenclature_item_id: "#{heading.short_code}#{6.times.map { Random.rand(9) }.join}",
        )
        create(
          :measure,
          :with_base_regulation,
          :third_country_overview,
          goods_nomenclature_sid: commodity.goods_nomenclature_sid,
        )
      end

      it { expect(serializable_hash.chapter).to equal(nil) }
      it { expect(serializable_hash.chapter_id).to equal(nil) }
    end

    context 'when commodity has not valid period' do
      before do
        create(
          :footnote,
          :with_gono_association,
          :with_description,
          goods_nomenclature_sid: heading.goods_nomenclature_sid,
        )
        create(
          :chapter,
          :with_section,
          :with_description,
          goods_nomenclature_item_id: heading.chapter_id,
        )
        create(
          :goods_nomenclature,
          :with_description,
          :with_indent,
          validity_start_date: 1.week.ago.beginning_of_day,
          validity_end_date: Time.zone.yesterday,
          goods_nomenclature_item_id: "#{heading.short_code}#{6.times.map { Random.rand(9) }.join}",
        )
        create(
          :measure,
          :with_base_regulation,
          :third_country_overview,
          goods_nomenclature_sid: heading.goods_nomenclature_sid,
        )
      end

      it { expect(serializable_hash.commodities).to be_empty }
    end

    context 'when overview measures has not valid period' do
      before do
        create(
          :footnote,
          :with_gono_association,
          :with_description,
          goods_nomenclature_sid: heading.goods_nomenclature_sid,
        )
        create(
          :chapter,
          :with_section,
          :with_description,
          goods_nomenclature_item_id: heading.chapter_id,
        )
        commodity = create(
          :goods_nomenclature,
          :with_description,
          :with_indent,
          goods_nomenclature_item_id: "#{heading.short_code}#{6.times.map { Random.rand(9) }.join}",
        )
        create(
          :measure,
          :with_base_regulation,
          :third_country_overview,
          validity_start_date: 1.week.ago.beginning_of_day,
          validity_end_date: Time.zone.yesterday,
          goods_nomenclature_sid: commodity.goods_nomenclature_sid,
        )
      end

      it { expect(serializable_hash.commodities).not_to be_empty }
      it { expect(serializable_hash.commodities.first.overview_measures).to be_empty }
    end

    it 'calls the AnnotatedCommodityService' do
      allow(AnnotatedCommodityService).to receive(:new).with(an_instance_of(Hashie::TariffMash)).and_call_original
      serializable_hash
      expect(AnnotatedCommodityService).to have_received(:new)
    end
  end
end
