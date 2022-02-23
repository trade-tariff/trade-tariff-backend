RSpec.describe Commodity do
  it 'has primary key set to goods_nomenclature_sid' do
    expect(subject.primary_key).to eq :goods_nomenclature_sid
  end

  describe 'associations' do
    describe 'heading' do
      let!(:gono1) do
        create :commodity, validity_start_date: Date.new(1999, 1, 1),
                           validity_end_date: Date.new(2013, 1, 1)
      end
      let!(:gono2) do
        create :commodity, goods_nomenclature_item_id: gono1.goods_nomenclature_item_id,
                           validity_start_date: Date.new(2005, 1, 1),
                           validity_end_date: Date.new(2013, 1, 1)
      end
      let!(:heading1) do
        create :heading, goods_nomenclature_item_id: "#{gono1.goods_nomenclature_item_id.first(4)}000000",
                         validity_start_date: Date.new(1991, 1, 1),
                         validity_end_date: Date.new(2002, 1, 1),
                         producline_suffix: '80'
      end
      let!(:heading2) do
        create :heading, goods_nomenclature_item_id: "#{gono1.goods_nomenclature_item_id.first(4)}000000",
                         validity_start_date: Date.new(2002, 1, 1),
                         validity_end_date: Date.new(2014, 1, 1),
                         producline_suffix: '80'
      end

      context 'fetching actual' do
        it 'fetches correct chapter' do
          TimeMachine.at('2000-1-1') do
            expect(gono1.reload.heading.pk).to eq heading1.pk
          end
          TimeMachine.at('2010-1-1') do
            expect(gono1.reload.heading.pk).to eq heading2.pk
          end
        end
      end

      context 'fetching relevant' do
        it 'fetches correct chapter' do
          TimeMachine.with_relevant_validity_periods do
            expect(gono2.reload.heading.pk).to eq heading2.pk
          end
        end
      end

      context 'heading with sub-headings' do
        # Example from real world scenario
        # https://www.pivotaltracker.com/story/show/55703384

        let!(:sub_heading) do
          create :heading, goods_nomenclature_item_id: '6308000000',
                           goods_nomenclature_sid: 43_837,
                           producline_suffix: '10',
                           validity_start_date: Date.new(1972, 1, 1)
        end
        let!(:heading) do
          create :heading, goods_nomenclature_item_id: '6308000000',
                           goods_nomenclature_sid: 43_838,
                           producline_suffix: '80',
                           validity_start_date: Date.new(1972, 1, 1)
        end
        let!(:commodity) do
          create :commodity, :with_indent,
                 :with_description,
                 indents: 1,
                 goods_nomenclature_sid: 91_335,
                 goods_nomenclature_item_id: '6308000015',
                 producline_suffix: '80',
                 validity_start_date: Date.new(2009, 7, 1)
        end

        it 'correctly identifies heading' do
          expect(commodity.heading).to eq heading
        end
      end
    end

    describe 'chapter' do
      let!(:gono1) do
        create :heading, validity_start_date: Date.new(1999, 1, 1),
                         validity_end_date: Date.new(2013, 1, 1)
      end
      let!(:gono2) do
        create :heading, goods_nomenclature_item_id: gono1.goods_nomenclature_item_id,
                         validity_start_date: Date.new(2005, 1, 1),
                         validity_end_date: Date.new(2013, 1, 1)
      end
      let!(:chapter1) do
        create :chapter, goods_nomenclature_item_id: "#{gono1.goods_nomenclature_item_id.first(2)}00000000",
                         validity_start_date: Date.new(1991, 1, 1),
                         validity_end_date: Date.new(2002, 1, 1)
      end
      let!(:chapter2) do
        create :chapter, goods_nomenclature_item_id: "#{gono1.goods_nomenclature_item_id.first(2)}00000000",
                         validity_start_date: Date.new(2002, 1, 1),
                         validity_end_date: Date.new(2014, 1, 1)
      end

      context 'fetching actual' do
        it 'fetches correct chapter' do
          TimeMachine.at('2000-1-1') do
            expect(gono1.reload.chapter.pk).to eq chapter1.pk
          end
          TimeMachine.at('2010-1-1') do
            expect(gono1.reload.chapter.pk).to eq chapter2.pk
          end
        end
      end

      context 'fetching relevant' do
        it 'fetches correct chapter' do
          TimeMachine.with_relevant_validity_periods do
            expect(gono2.reload.chapter.pk).to eq chapter2.pk
          end
        end
      end
    end

    describe '#measures' do
      let(:commodity) { create :commodity, :with_indent }
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
          measure = create(:measure, :with_base_regulation, measure_type_id: measure_type.measure_type_id, goods_nomenclature_sid: commodity.goods_nomenclature_sid)

          expect(commodity.measures.map(&:measure_sid)).not_to include measure.measure_sid
        end

        it 'does include quota measures that are only excluded for the XI service' do
          measure_type = create(:measure_type, measure_type_id: excluded_quota_for_xi)
          measure = create(:measure, :with_base_regulation, measure_type_id: measure_type.measure_type_id, goods_nomenclature_sid: commodity.goods_nomenclature_sid)

          expect(commodity.measures.map(&:measure_sid)).to include measure.measure_sid
        end

        it 'does include P&R national measures that are only excluded for the XI service' do
          measure_type = create(:measure_type, measure_type_id: excluded_pr_for_xi)
          measure = create(:measure, :with_base_regulation, measure_type_id: measure_type.measure_type_id, goods_nomenclature_sid: commodity.goods_nomenclature_sid)

          expect(commodity.measures.map(&:measure_sid)).to include measure.measure_sid
        end
      end

      context 'when the service version is the XI' do
        let(:service) { 'xi' }

        it 'does not include measures that were also excluded for the UK service' do
          measure_type = create(:measure_type, measure_type_id: excluded_for_both_uk_xi)
          measure = create(:measure, :with_base_regulation, measure_type_id: measure_type.measure_type_id, goods_nomenclature_sid: commodity.goods_nomenclature_sid)

          expect(commodity.measures.map(&:measure_sid)).not_to include measure.measure_sid
        end

        it 'does not include quota measures that are only excluded for the XI service' do
          measure_type = create(:measure_type, measure_type_id: excluded_quota_for_xi)
          measure = create(:measure, :with_base_regulation, measure_type_id: measure_type.measure_type_id, goods_nomenclature_sid: commodity.goods_nomenclature_sid)

          expect(commodity.measures.map(&:measure_sid)).not_to include measure.measure_sid
        end

        it 'does not include P&R national measures that are only excluded for the XI service' do
          measure_type = create(:measure_type, measure_type_id: excluded_pr_for_xi)
          measure = create(:measure, :with_base_regulation, measure_type_id: measure_type.measure_type_id, goods_nomenclature_sid: commodity.goods_nomenclature_sid)

          expect(commodity.measures.map(&:measure_sid)).not_to include measure.measure_sid
        end
      end
    end

    describe 'measure duplication' do
      # sometimes measures have the same base regulation id and
      # validity_start date
      # need to group and choose the latest one
      let(:measure_type) { create :measure_type }
      let(:commodity)    { create :commodity, :with_indent, validity_start_date: 3.years.ago.beginning_of_day }
      let!(:measure1)    do
        create :measure, :with_base_regulation, measure_sid: 1,
                         measure_type_id: measure_type.measure_type_id,
                         additional_code_type_id: nil,
                         goods_nomenclature_sid: commodity.goods_nomenclature_sid,
                         validity_start_date: 1.year.ago.beginning_of_day
      end
      let!(:measure2) do
        create :measure, :with_base_regulation, measure_sid: 2,
                         measure_generating_regulation_id: measure1.measure_generating_regulation_id,
                         geographical_area_id: measure1.geographical_area_id,
                         measure_type_id: measure_type.measure_type_id,
                         geographical_area_sid: measure1.geographical_area_sid,
                         goods_nomenclature_sid: commodity.goods_nomenclature_sid,
                         additional_code_type_id: measure1.additional_code_type_id,
                         additional_code_id: measure1.additional_code_id,
                         validity_start_date: 2.years.ago.beginning_of_day
      end

      it 'groups measures by measure_generating_regulation_id and picks latest one' do
        TimeMachine.at(Time.zone.today) do
          expect(commodity.measures.map(&:measure_sid)).to     include measure1.measure_sid
          expect(commodity.measures.map(&:measure_sid)).not_to include measure2.measure_sid
        end
      end
    end

    describe 'measures for export' do
      context 'trade movement code' do
        let(:export_measure_type) { create :measure_type, :export }
        let(:commodity1)          { create :commodity, :with_indent }
        let(:export_measure)      do
          create :measure, :with_base_regulation, measure_type_id: export_measure_type.measure_type_id,
                           goods_nomenclature_sid: commodity1.goods_nomenclature_sid
        end

        let(:import_measure_type) { create :measure_type, :import }
        let(:commodity2)          { create :commodity, :with_indent }
        let(:import_measure)      do
          create :measure, :with_base_regulation, measure_type_id: import_measure_type.measure_type_id,
                           goods_nomenclature_sid: commodity2.goods_nomenclature_sid
        end

        it 'fetches measures that have measure type with proper trade movement code' do
          export_measure_type
          export_measure

          import_measure_type
          import_measure

          expect(commodity1.export_measures.map(&:measure_sid)).to     include export_measure.measure_sid
          expect(commodity1.export_measures.map(&:measure_sid)).not_to include import_measure.measure_sid

          expect(commodity2.import_measures.map(&:measure_sid)).to     include import_measure.measure_sid
          expect(commodity2.import_measures.map(&:measure_sid)).not_to include export_measure.measure_sid
        end
      end

      context 'export refund nomenclature' do
        let!(:commodity) { create :commodity, :with_indent }
        let!(:export_refund_nomenclature) do
          create :export_refund_nomenclature, :with_indent,
                 goods_nomenclature_sid: commodity.goods_nomenclature_sid
        end
        let!(:export_measure) do
          create :measure, :with_base_regulation, export_refund_nomenclature_sid: export_refund_nomenclature.export_refund_nomenclature_sid,
                           goods_nomenclature_item_id: commodity.goods_nomenclature_item_id
        end

        it 'includes measures that belongs to related export refund nomenclature' do
          expect(commodity.measures).not_to be_blank
          expect(commodity.measures.map(&:measure_sid)).to include export_measure.measure_sid
        end
      end
    end

    describe 'measures and base_regulations' do
      let!(:commodity) do
        create :commodity, :with_indent,
               validity_start_date: Time.zone.now.ago(10.years)
      end
      let!(:measure_type)    { create :measure_type }
      let!(:base_regulation) { create :base_regulation, effective_end_date: Time.zone.now.ago(1.month) }
      let!(:measure1)        do
        create :measure, measure_generating_regulation_id: base_regulation.base_regulation_id,
                         validity_end_date: Time.zone.now.ago(30.months),
                         goods_nomenclature_sid: commodity.goods_nomenclature_sid,
                         validity_start_date: Time.zone.now.ago(10.years),
                         measure_type_id: measure_type.measure_type_id,
                         geographical_area_sid: 1
      end
      let!(:measure2) do
        create :measure, measure_generating_regulation_id: base_regulation.base_regulation_id,
                         goods_nomenclature_sid: commodity.goods_nomenclature_sid,
                         measure_type_id: measure_type.measure_type_id,
                         validity_start_date: Time.zone.now.ago(10.years),
                         validity_end_date: Time.zone.now.ago(18.months),
                         geographical_area_sid: 2
      end
      let!(:measure3) do
        create :measure, measure_generating_regulation_id: base_regulation.base_regulation_id,
                         goods_nomenclature_sid: commodity.goods_nomenclature_sid,
                         measure_type_id: measure_type.measure_type_id,
                         validity_start_date: Time.zone.now.ago(10.years),
                         validity_end_date: nil,
                         geographical_area_sid: 3
      end

      it 'measure validity date superseeds regulation validity date' do
        measures = TimeMachine.at(Time.zone.now.ago(1.year)) { described_class.actual.first.measures }.map(&:measure_sid)
        expect(measures).to     include measure3.measure_sid
        expect(measures).not_to include measure2.measure_sid
        expect(measures).not_to include measure1.measure_sid

        measures = TimeMachine.at(Time.zone.now.ago(2.years)) { described_class.actual.first.measures }.map(&:measure_sid)
        expect(measures).to     include measure3.measure_sid
        expect(measures).to     include measure2.measure_sid
        expect(measures).not_to include measure1.measure_sid

        measures = TimeMachine.at(Time.zone.now.ago(3.years)) { described_class.actual.first.measures }.map(&:measure_sid)
        expect(measures).to     include measure3.measure_sid
        expect(measures).to     include measure2.measure_sid
        expect(measures).to     include measure1.measure_sid
      end
    end

    describe 'measures and modification_regulations' do
      let!(:commodity) do
        create :commodity, :with_indent,
               validity_start_date: Time.zone.now.ago(10.years)
      end
      let!(:measure_type) { create :measure_type }
      let!(:modification_regulation) { create :modification_regulation, effective_end_date: Time.zone.now.ago(1.month) }
      let!(:measure1) do
        create :measure, :with_base_regulation,
                         measure_generating_regulation_id: modification_regulation.modification_regulation_id,
                         validity_end_date: Time.zone.now.ago(30.months),
                         goods_nomenclature_sid: commodity.goods_nomenclature_sid,
                         validity_start_date: Time.zone.now.ago(10.years),
                         measure_type_id: measure_type.measure_type_id,
                         geographical_area_sid: 1
      end
      let!(:measure2) do
        create :measure, :with_base_regulation,
                         measure_generating_regulation_id: modification_regulation.modification_regulation_id,
                         goods_nomenclature_sid: commodity.goods_nomenclature_sid,
                         measure_type_id: measure_type.measure_type_id,
                         validity_start_date: Time.zone.now.ago(10.years),
                         validity_end_date: Time.zone.now.ago(18.months),
                         geographical_area_sid: 2
      end
      let!(:measure3) do
        create :measure, :with_base_regulation,
                         measure_generating_regulation_id: modification_regulation.modification_regulation_id,
                         goods_nomenclature_sid: commodity.goods_nomenclature_sid,
                         measure_type_id: measure_type.measure_type_id,
                         validity_start_date: Time.zone.now.ago(10.years),
                         validity_end_date: nil,
                         geographical_area_sid: 3
      end

      it 'measure validity date supercedes regulation validity date' do
        measures = TimeMachine.at(Time.zone.now.ago(1.year)) { described_class.actual.first.measures }.map(&:measure_sid)
        expect(measures).to     include measure3.measure_sid
        expect(measures).not_to include measure2.measure_sid
        expect(measures).not_to include measure1.measure_sid

        measures = TimeMachine.at(Time.zone.now.ago(2.years)) { described_class.actual.first.measures }.map(&:measure_sid)
        expect(measures).to     include measure3.measure_sid
        expect(measures).to     include measure2.measure_sid
        expect(measures).not_to include measure1.measure_sid

        measures = TimeMachine.at(Time.zone.now.ago(3.years)) { described_class.actual.first.measures }.map(&:measure_sid)
        expect(measures).to     include measure3.measure_sid
        expect(measures).to     include measure2.measure_sid
        expect(measures).to     include measure1.measure_sid
      end
    end
  end

  describe '#to_param' do
    let(:commodity) { create :commodity }

    it 'uses goods_nomenclature_item_id as param' do
      expect(commodity.to_param).to eq commodity.goods_nomenclature_item_id
    end
  end

  describe '.actual' do
    let!(:actual_commodity)  { create :commodity, :actual }
    let!(:expired_commodity) { create :commodity, :expired }

    context 'when not in TimeMachine block' do
      it 'fetches all commodities' do
        commodities = described_class.all
        expect(commodities).to include actual_commodity
        expect(commodities).to include expired_commodity
      end
    end

    context 'when in TimeMachine block' do
      it 'fetches commodities that are actual on specified Date' do
        TimeMachine.at(2.years.ago.beginning_of_day) do
          commodities = described_class.actual.all
          expect(commodities).to include actual_commodity
          expect(commodities).to include expired_commodity
        end
      end
    end
  end

  describe '#children' do
    let!(:heading) do
      create :heading, goods_nomenclature_item_id: '8418000000',
                       validity_start_date: Date.new(2011, 1, 1)
    end
    let!(:commodity1) do
      create :commodity, :with_indent,
             indents: 3,
             goods_nomenclature_item_id: '8418211000',
             producline_suffix: '80',
             validity_start_date: Date.new(2011, 1, 1)
    end
    let!(:commodity2) do
      create :commodity, :with_indent,
             indents: 3,
             goods_nomenclature_item_id: '8418215100',
             producline_suffix: '10',
             validity_start_date: Date.new(2011, 1, 1)
    end
    let!(:commodity3) do
      create :commodity, :with_indent,
             indents: 4,
             goods_nomenclature_item_id: '8418215100',
             producline_suffix: '80',
             validity_start_date: Date.new(2011, 1, 1)
    end

    around do |example|
      TimeMachine.at(Date.new(2011, 2, 1)) do
        example.run
      end
    end

    it 'does not returns children if there are no commodities with higher indent levels and item ids' do
      expect(commodity1.children).to be_empty
    end

    it 'returns children commodities with higher ident levels and items ids' do
      expect(commodity2.children.map(&:pk)).to include commodity3.pk
    end

    context 'when the BufferHeadingCommoditiesService has ran' do
      around do |example|
        BufferHeadingCommoditiesService.new.call do
          example.call
        end
      end

      it 'returns children commodities with higher ident levels and items ids' do
        expect(commodity2.children.map(&:pk)).to include commodity3.pk
      end
    end
  end

  describe '#ancestors' do
    describe 'comparing indent numbers' do
      let!(:commodity) do
        create :commodity, :with_indent, :with_description,
               indents: 7,
               goods_nomenclature_item_id: '2204219711',
               producline_suffix: '80',
               validity_start_date: Date.new(2010, 1, 1)
      end

      let!(:ancestor_commodity) do
        create :commodity, :with_description,
               goods_nomenclature_item_id: '2204218900',
               producline_suffix: '80',
               validity_start_date: Date.new(1995, 1, 1)
      end
      let!(:indent1) do
        create(:goods_nomenclature_indent,
               goods_nomenclature_sid: ancestor_commodity.goods_nomenclature_sid,
               goods_nomenclature_item_id: ancestor_commodity.goods_nomenclature_item_id,
               number_indents: 7,
               validity_start_date: Date.new(2010, 1, 1))
      end
      let!(:indent2) do
        create(:goods_nomenclature_indent,
               number_indents: 7,
               goods_nomenclature_sid: ancestor_commodity.goods_nomenclature_sid,
               goods_nomenclature_item_id: ancestor_commodity.goods_nomenclature_item_id,
               validity_start_date: Date.new(1995, 1, 1))
      end

      it 'does not pick ancestor_commodity as ancestor (indent number is not lower (same level))' do
        expect(commodity.ancestors).to eq([])
      end
    end

    describe 'nested commodities' do
      let!(:chapter) do
        create :chapter, goods_nomenclature_item_id: '8500000000',
                         validity_start_date: Date.new(2010, 1, 1),
                         producline_suffix: '80'
      end
      let!(:heading) do
        create :heading, goods_nomenclature_item_id: '8504000000',
                         validity_start_date: Date.new(2010, 1, 1),
                         producline_suffix: '80'
      end
      let!(:commodity0) do
        create :commodity, :with_indent, :with_description,
               indents: 4,
               goods_nomenclature_item_id: '8504909990',
               producline_suffix: '80',
               validity_start_date: Date.new(2010, 1, 1)
      end
      let!(:commodity1) do
        create :commodity, :with_indent, :with_description,
               indents: 3,
               goods_nomenclature_item_id: '8504909900',
               producline_suffix: '80',
               validity_start_date: Date.new(2010, 1, 1)
      end
      let!(:commodity2) do
        create :commodity, :with_indent, :with_description,
               indents: 2,
               goods_nomenclature_item_id: '8504909100',
               producline_suffix: '80',
               validity_start_date: Date.new(2010, 1, 1)
      end
      let!(:commodity3) do
        create :commodity, :with_indent, :with_description,
               indents: 1,
               goods_nomenclature_item_id: '8504900000',
               producline_suffix: '80',
               validity_start_date: Date.new(2010, 1, 1)
      end
      let!(:commodity4) do
        create :commodity, :with_indent, :with_description,
               indents: 2,
               goods_nomenclature_item_id: '8504900500',
               producline_suffix: '80',
               validity_start_date: Date.new(2010, 1, 1)
      end
      let!(:commodity5) do
        create :commodity, :with_indent, :with_description,
               indents: 3,
               goods_nomenclature_item_id: '8504901100',
               producline_suffix: '80',
               validity_start_date: Date.new(2010, 1, 1)
      end
      let!(:commodity6) do
        create :commodity, :with_indent, :with_description,
               indents: 4,
               goods_nomenclature_item_id: '8504901100',
               producline_suffix: '80',
               validity_start_date: Date.new(2010, 1, 1)
      end
      let!(:commodity7) do
        create :commodity, :with_indent, :with_description,
               indents: 5,
               goods_nomenclature_item_id: '8504901190',
               producline_suffix: '80',
               validity_start_date: Date.new(2010, 1, 1)
      end
      let!(:commodity8) do
        create :commodity, :with_indent, :with_description,
               indents: 3,
               goods_nomenclature_item_id: '8504900500',
               producline_suffix: '80',
               validity_start_date: Date.new(2010, 1, 1)
      end
      let!(:commodity9) do
        create :commodity, :with_indent, :with_description,
               indents: 4,
               goods_nomenclature_item_id: '8504901800',
               producline_suffix: '80',
               validity_start_date: Date.new(2010, 1, 1)
      end
      let!(:commodity10) do
        create :commodity, :with_indent, :with_description,
               indents: 5,
               goods_nomenclature_item_id: '8504901899',
               producline_suffix: '80',
               validity_start_date: Date.new(2010, 1, 1)
      end
      let!(:commodity11) do
        create :commodity, :with_indent, :with_description,
               indents: 3,
               goods_nomenclature_item_id: '8504909100',
               producline_suffix: '80',
               validity_start_date: Date.new(2010, 1, 1)
      end
      let!(:commodity12) do
        create :commodity, :with_indent, :with_description,
               indents: 5,
               goods_nomenclature_item_id: '8504901110',
               producline_suffix: '80',
               validity_start_date: Date.new(2010, 1, 1)
      end
      let!(:commodity13) do
        create :commodity, :with_indent, :with_description,
               indents: 5,
               goods_nomenclature_item_id: '8504901120',
               producline_suffix: '80',
               validity_start_date: Date.new(2010, 1, 1)
      end

      around do |example|
        TimeMachine.at(Date.new(2011, 2, 1)) do
          example.run
        end
      end

      it 'returns valid ancestors' do
        expect(commodity0.ancestors.map(&:goods_nomenclature_item_id)).to eq(%w[8504900000 8504909100 8504909900])
        expect(commodity7.ancestors.map(&:goods_nomenclature_item_id)).to eq(%w[8504900000 8504900500 8504901100 8504901100])
        expect(commodity10.ancestors.map(&:goods_nomenclature_item_id)).to eq(%w[8504900000 8504900500 8504901100 8504901800])
      end

      it 'returns ancestors with indent less then current commodity indent' do
        expect(commodity0.ancestors.map(&:number_indents)).to all(be < commodity0.number_indents)
      end
    end
  end

  describe '#changes' do
    let(:commodity) { create :commodity }

    it 'returns Sequel Dataset' do
      expect(commodity.changes).to be_kind_of Sequel::Dataset
    end

    context 'with commodity changes' do
      let!(:commodity) { create :commodity, operation_date: Time.zone.today }

      it 'includes commodity changes' do
        expect(
          commodity.changes.select do |change|
            change.oid == commodity.oid &&
            change.model == GoodsNomenclature
          end,
        ).to be_present
      end
    end

    context 'with associated measure changes' do
      let!(:commodity) { create :commodity, operation_date: Time.zone.yesterday }
      let!(:measure)   do
        create :measure,
               goods_nomenclature: commodity,
               goods_nomenclature_item_id: commodity.goods_nomenclature_item_id,
               operation_date: Time.zone.today
      end

      it 'includes measure changes' do
        expect(
          commodity.changes.select do |change|
            change.oid == measure.oid &&
            change.model == Measure
          end,
        ).to be_present
      end
    end
  end

  describe '#declarable?' do
    let(:commodity_80) { create(:commodity, producline_suffix: '80') }
    let(:commodity_10) { create(:commodity, producline_suffix: '10') }

    context 'with children' do
      before do
        allow_any_instance_of(described_class).to receive(:children).and_return([1])
      end

      it "returns true for producline_suffix == '80'" do
        expect(commodity_80).not_to be_declarable
      end

      it 'returns false for other producline_suffix' do
        expect(commodity_10).not_to be_declarable
      end
    end

    context 'without children' do
      before do
        allow_any_instance_of(described_class).to receive(:children).and_return([])
      end

      it "returns true for producline_suffix == '80'" do
        expect(commodity_80).to be_declarable
      end

      it 'returns false for other producline_suffix' do
        expect(commodity_10).not_to be_declarable
      end
    end
  end

  describe '.declarable' do
    let(:commodity_80) { create(:commodity, producline_suffix: '80') }
    let(:commodity_10) { create(:commodity, producline_suffix: '10') }

    it "returns commodities ony with producline_suffix == '80'" do
      commodities = described_class.declarable
      expect(commodities).to include(commodity_80)
      expect(commodities).not_to include(commodity_10)
    end
  end

  describe '.by_code' do
    let(:commodity1) { create(:commodity, goods_nomenclature_item_id: '123') }
    let(:commodity2) { create(:commodity, goods_nomenclature_item_id: '456') }

    it 'returns commodities filtered by goods_nomenclature_item_id' do
      commodities = described_class.by_code('123')
      expect(commodities).to include(commodity1)
      expect(commodities).not_to include(commodity2)
    end
  end

  describe '.by_productline_suffix' do
    subject(:result) { described_class.by_productline_suffix('10').all }

    before do
      declarable_commodity
      non_declarable_commodity
    end

    let(:declarable_commodity) { create(:commodity, producline_suffix: '80') }
    let(:non_declarable_commodity) { create(:commodity, producline_suffix: '10') }

    it { expect(result).to eq([non_declarable_commodity]) }
  end

  describe '.heading_short_code' do
    subject(:heading_short_code) { build(:commodity, goods_nomenclature_item_id: '0101000000').heading_short_code }

    it { is_expected.to eq('0101') }
  end
end
