RSpec.describe Heading do
  describe '#to_param' do
    let(:heading) { create :heading }

    it 'uses first four digits of goods_nomenclature_item_id as param' do
      expect(
        heading.to_param,
      ).to eq heading.goods_nomenclature_item_id.first(4)
    end
  end

  describe 'associations' do
    describe 'chapter' do
      let!(:heading1)  do
        create :heading, validity_start_date: Date.new(1999, 1, 1),
                         validity_end_date: Date.new(2013, 1, 1)
      end
      let!(:heading2) do
        create :heading, goods_nomenclature_item_id: heading1.goods_nomenclature_item_id,
                         validity_start_date: Date.new(2005, 1, 1),
                         validity_end_date: Date.new(2013, 1, 1)
      end
      let!(:chapter1) do
        create :chapter, goods_nomenclature_item_id: "#{heading1.goods_nomenclature_item_id.first(2)}00000000",
                         validity_start_date: Date.new(1991, 1, 1),
                         validity_end_date: Date.new(2002, 1, 1)
      end
      let!(:chapter2) do
        create :chapter, goods_nomenclature_item_id: "#{heading1.goods_nomenclature_item_id.first(2)}00000000",
                         validity_start_date: Date.new(2002, 1, 1),
                         validity_end_date: Date.new(2014, 1, 1)
      end

      context 'fetching actual' do
        it 'fetches correct chapter' do
          TimeMachine.at('2000-1-1') do
            expect(
              heading1.reload.chapter.pk,
            ).to eq chapter1.pk
          end
          TimeMachine.at('2010-1-1') do
            expect(
              heading1.reload.chapter.pk,
            ).to eq chapter2.pk
          end
        end
      end

      context 'fetching relevant' do
        it 'fetches correct chapter' do
          TimeMachine.with_relevant_validity_periods do
            expect(
              heading2.reload.chapter.pk,
            ).to eq chapter2.pk
          end
        end
      end
    end

    describe '#measures' do
      let(:heading) { create :commodity, :with_indent }
      let(:excluded_for_both_uk_xi) { '442' }
      let(:excluded_quota_for_xi) { '653' }
      let(:excluded_pr_for_xi) { 'CEX' }

      before do
        allow(TradeTariffBackend).to receive(:service).and_return(service)
      end

      context 'when the service version is the UK' do
        let(:service) { 'uk' }

        it 'does not include measures that are excluded for the UK service' do
          measure_type = create(:measure_type, measure_type_id: excluded_for_both_uk_xi)
          measure = create(:measure, :with_base_regulation, measure_type_id: measure_type.measure_type_id, goods_nomenclature_sid: heading.goods_nomenclature_sid)

          expect(heading.measures.map(&:measure_sid)).not_to include measure.measure_sid
        end

        it 'does include quota measures that are only excluded for the XI service' do
          measure_type = create(:measure_type, measure_type_id: excluded_quota_for_xi)
          measure = create(:measure, :with_base_regulation, measure_type_id: measure_type.measure_type_id, goods_nomenclature_sid: heading.goods_nomenclature_sid)

          expect(heading.measures.map(&:measure_sid)).to include measure.measure_sid
        end

        it 'does include P&R national measures that are only excluded for the XI service' do
          measure_type = create(:measure_type, measure_type_id: excluded_pr_for_xi)
          measure = create(:measure, :with_base_regulation, measure_type_id: measure_type.measure_type_id, goods_nomenclature_sid: heading.goods_nomenclature_sid)

          expect(heading.measures.map(&:measure_sid)).to include measure.measure_sid
        end
      end

      context 'when the service version is XI' do
        let(:service) { 'xi' }

        it 'does not include measures that were also excluded for the UK service' do
          measure_type = create(:measure_type, measure_type_id: excluded_for_both_uk_xi)
          measure = create(:measure, :with_base_regulation, measure_type_id: measure_type.measure_type_id, goods_nomenclature_sid: heading.goods_nomenclature_sid)

          expect(heading.measures.map(&:measure_sid)).not_to include measure.measure_sid
        end

        it 'does not include quota measures that are only excluded for the XI service' do
          measure_type = create(:measure_type, measure_type_id: excluded_quota_for_xi)
          measure = create(:measure, :with_base_regulation, measure_type_id: measure_type.measure_type_id, goods_nomenclature_sid: heading.goods_nomenclature_sid)

          expect(heading.measures.map(&:measure_sid)).not_to include measure.measure_sid
        end

        it 'does not include national P&R national measures that are only excluded for the XI service' do
          measure_type = create(:measure_type, measure_type_id: excluded_pr_for_xi)
          measure = create(:measure, :with_base_regulation, measure_type_id: measure_type.measure_type_id, goods_nomenclature_sid: heading.goods_nomenclature_sid)

          expect(heading.measures.map(&:measure_sid)).not_to include measure.measure_sid
        end
      end
    end

    describe 'commodities' do
      let!(:heading)    { create :heading }
      let!(:commodity1) do
        create :commodity, goods_nomenclature_item_id: "#{heading.goods_nomenclature_item_id.first(4)}100000",
                           validity_start_date: 10.years.ago,
                           validity_end_date: nil
      end
      let!(:commodity2) do
        create :commodity, goods_nomenclature_item_id: "#{heading.goods_nomenclature_item_id.first(4)}200000",
                           validity_start_date: 2.years.ago,
                           validity_end_date: nil
      end
      let!(:commodity3) do
        create :commodity, goods_nomenclature_item_id: "#{heading.goods_nomenclature_item_id.first(4)}300000",
                           validity_start_date: 10.years.ago,
                           validity_end_date: 8.years.ago
      end

      around do |example|
        TimeMachine.at(1.year.ago) do
          example.run
        end
      end

      it 'returns commodities matched by part of own goods nomenclature item id' do
        expect(
          heading.commodities,
        ).to include commodity1
      end

      it 'returns relevant by actual time commodities' do
        expect(
          heading.commodities,
        ).to include commodity2
      end

      it 'does not return commodity that is irrelevant to given time' do
        expect(
          heading.commodities,
        ).not_to include commodity3
      end
    end

    describe 'chapter' do
      let!(:heading)  { create :heading }
      let!(:chapter1) do
        create :chapter, goods_nomenclature_item_id: "#{heading.goods_nomenclature_item_id.first(2)}00000000",
                         validity_start_date: 10.years.ago,
                         validity_end_date: nil
      end
      let!(:chapter2) do
        create :chapter, goods_nomenclature_item_id: "#{heading.goods_nomenclature_item_id.first(2)}00000000",
                         validity_start_date: 10.years.ago,
                         validity_end_date: 8.years.ago
      end

      around do |example|
        TimeMachine.at(1.year.ago) do
          example.run
        end
      end

      it 'returns chapter matched by part of own goods nomenclature item id' do
        expect(heading.chapter(reload: true)).to eq chapter1
      end

      it 'does not return commodity that is irrelevant to given time' do
        expect(heading.chapter(reload: true)).not_to eq chapter2
      end
    end
  end

  describe '#declarable' do
    context 'different points in time' do
      today = Time.zone.today
      t1 = today.ago(2.years)
      t2 = today.ago(1.year)
      let!(:declarable_heading) { create :heading, :declarable, goods_nomenclature_item_id: '0102000000', validity_start_date: t1, validity_end_date: nil }
      let!(:commodity) do
        create :commodity, goods_nomenclature_item_id: '0102000010',
                           producline_suffix: '80',
                           validity_start_date: t1,
                           validity_end_date: t2
      end

      it 'returns true if there are no commodities under this heading that are valid during headings validity period' do
        TimeMachine.now do
          expect(
            declarable_heading.declarable,
          ).to be_truthy
        end
      end

      it 'returns false if there are commodities under the heading that are valid during headings validity period' do
        TimeMachine.at(t2.ago(1.day)) do
          expect(
            declarable_heading.declarable,
          ).to be_falsy
        end
      end
    end

    context 'different commodity codes' do
      let!(:declarable_heading)     { create :heading, :declarable, goods_nomenclature_item_id: '0101000000' }
      let!(:non_declarable_heading) { create :heading, goods_nomenclature_item_id: '0102000000', producline_suffix: '10' }
      let!(:commodity)              do
        create :commodity, goods_nomenclature_item_id: '0102000010',
                           producline_suffix: '80',
                           validity_start_date: non_declarable_heading.validity_start_date,
                           validity_end_date: non_declarable_heading.validity_end_date
      end

      it 'returns true if there are no commodities under this heading that are valid during headings validity period' do
        expect(
          declarable_heading.declarable,
        ).to be_truthy
      end

      it 'returns false if there are commodities under the heading that are valid during headings validity period' do
        expect(
          non_declarable_heading.declarable,
        ).to be_falsy
      end
    end

    context 'same commodity codes' do
      let!(:heading1) do
        create :heading, goods_nomenclature_item_id: '0101000000',
                         producline_suffix: '10'
      end
      let!(:heading2) do
        create :heading, goods_nomenclature_item_id: '0101000000',
                         producline_suffix: '80'
      end

      it 'returns true if there are no commodities under this heading that are valid during headings validity period' do
        expect(
          heading1.declarable,
        ).to be_falsy
      end

      it 'returns false if there are commodities under the heading that are valid during headings validity period' do
        expect(
          heading2.declarable,
        ).to be_truthy
      end
    end
  end

  describe '#changes' do
    let(:heading) { create :heading }

    it 'returns Sequel Dataset' do
      expect(heading.changes).to be_kind_of Sequel::Dataset
    end

    context 'with Heading changes' do
      let!(:heading) { create :heading, operation_date: Time.zone.today }

      it 'includes Heading changes' do
        expect(
          heading.changes.select do |change|
            change.oid == heading.oid &&
            change.model == described_class
          end,
        ).to be_present
      end
    end

    context 'with associated Commodity changes' do
      let!(:heading)   { create :heading, operation_date: Time.zone.yesterday }
      let!(:commodity) do
        create :commodity,
               operation_date: Time.zone.yesterday,
               goods_nomenclature_item_id: "#{heading.short_code}000001"
      end

      it 'includes Commodity changes' do
        expect(
          heading.changes.select do |change|
            change.oid == commodity.oid &&
            change.model == Commodity
          end,
        ).to be_present
      end

      context 'with associated Measure (through Commodity) changes' do
        let!(:heading)   { create :heading, operation_date: Time.zone.yesterday }
        let!(:commodity) do
          create :commodity,
                 operation_date: Time.zone.yesterday,
                 goods_nomenclature_item_id: "#{heading.short_code}000001"
        end
        let!(:measure) do
          create :measure,
                 goods_nomenclature: commodity,
                 goods_nomenclature_item_id: commodity.goods_nomenclature_item_id,
                 operation_date: Time.zone.yesterday
        end

        it 'includes Measure changes' do
          expect(
            heading.changes.select do |change|
              change.oid == measure.oid &&
              change.model == Measure
            end,
          ).to be_present
        end
      end
    end
  end

  describe '#short_code' do
    let!(:heading) { create :heading, goods_nomenclature_item_id: '1234000000' }

    it 'returns first 4 chars of goods_nomenclature_item_id' do
      expect(heading.short_code).to eq('1234')
    end
  end

  describe '.declarable' do
    let(:heading_80) { create(:heading, producline_suffix: '80') }
    let(:heading_10) { create(:heading, producline_suffix: '10') }

    it "returns headings ony with producline_suffix == '80'" do
      headings = described_class.declarable
      expect(headings).to include(heading_80)
      expect(headings).not_to include(heading_10)
    end
  end

  describe '.by_code' do
    let!(:heading1) { create(:heading, goods_nomenclature_item_id: '1234000000') }
    let!(:heading2) { create(:heading, goods_nomenclature_item_id: '4321000000') }

    it 'returns headings filtered by goods_nomenclature_item_id' do
      headings = described_class.by_code('1234')
      expect(headings).to include(heading1)
      expect(headings).not_to include(heading2)
    end
  end
end
