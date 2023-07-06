RSpec.describe Measure do
  describe '#id' do
    let(:measure) { build :measure }

    it 'is an alias to #measure_sid' do
      expect(measure.id).to eq measure.measure_sid
    end
  end

  describe 'methods delegated to measure_type' do
    subject { build :measure }

    it { is_expected.to respond_to :rules_of_origin_apply? }
    it { is_expected.to respond_to :third_country? }
    it { is_expected.to respond_to :excise? }
    it { is_expected.to respond_to :vat? }
    it { is_expected.to respond_to :preferential_quota? }
    it { is_expected.to respond_to :tariff_preference? }
    it { is_expected.to respond_to :trade_remedy? }
  end

  describe '.effective_start_date_column' do
    subject(:sql_column) { described_class.effective_start_date_column }

    let :coalesced_columns do
      %i[
        measures__validity_start_date
        base_regulation__validity_start_date
        modification_regulation__validity_start_date
      ]
    end

    it { is_expected.to be_instance_of Sequel::SQL::Function }
    it { is_expected.to have_attributes name: :coalesce }
    it { is_expected.to have_attributes args: coalesced_columns }
  end

  describe '.effective_end_date_column' do
    subject(:sql_column) { described_class.effective_end_date_column }

    let :coalesced_columns do
      %i[
        measures__validity_end_date
        base_regulation__effective_end_date
        base_regulation__validity_end_date
        modification_regulation__effective_end_date
        modification_regulation__validity_end_date
      ]
    end

    it { is_expected.to be_instance_of Sequel::SQL::Function }
    it { is_expected.to have_attributes name: :coalesce }
    it { is_expected.to have_attributes args: coalesced_columns }
  end

  shared_examples 'includes measure type' do |measure_type, geographical_area|
    context %(with measures of type #{MeasureType.const_get(measure_type).first} are included#{" for #{geographical_area}" if geographical_area}) do
      let(:geographical_area_id) { geographical_area } if geographical_area
      let(:measure_type_id) { MeasureType.const_get(measure_type).first }

      it { is_expected.to include measure.measure_sid }
    end
  end

  shared_examples 'excludes measure type' do |measure_type, geographical_area|
    context %(with measures of type #{MeasureType.const_get(measure_type).first} are excluded#{" for #{geographical_area}" if geographical_area}) do
      let(:geographical_area_id) { geographical_area } if geographical_area
      let(:measure_type_id) { MeasureType.const_get(measure_type).first }

      it { is_expected.not_to include measure.measure_sid }
    end
  end

  describe '.without_excluded_types' do
    subject { measure.class.without_excluded_types.all.map(&:measure_sid) }

    before { allow(TradeTariffBackend).to receive(:service).and_return(service) }

    let(:measure) { create :measure, :with_base_regulation, measure_type_id: }

    context 'for UK service' do
      let(:service) { 'uk' }

      it_behaves_like 'excludes measure type', 'UK_EXCLUDED_TYPES'
    end

    context 'for XI service' do
      let(:service) { 'xi' }

      it_behaves_like 'excludes measure type', 'XI_EXCLUDED_TYPES'
    end
  end

  describe '.overview' do
    subject { measure.class.overview.all.map(&:measure_sid) }

    before { allow(TradeTariffBackend).to receive(:service).and_return(service) }

    let(:measure) do
      create :measure, :with_base_regulation, measure_type_id:,
                                              geographical_area_id:
    end

    let(:geographical_area_id) { GeographicalArea::ERGA_OMNES_ID }

    context 'for UK service' do
      let(:service) { 'uk' }

      it_behaves_like 'excludes measure type', 'TARIFF_PREFERENCE'
      it_behaves_like 'includes measure type', 'SUPPLEMENTARY_TYPES'
      it_behaves_like 'includes measure type', 'THIRD_COUNTRY'
      it_behaves_like 'excludes measure type', 'THIRD_COUNTRY', 'FR'
      it_behaves_like 'includes measure type', 'VAT_TYPES'
      it_behaves_like 'excludes measure type', 'VAT_TYPES', 'FR'
    end

    context 'for XI service' do
      let(:service) { 'xi' }

      it_behaves_like 'excludes measure type', 'TARIFF_PREFERENCE'
      it_behaves_like 'includes measure type', 'SUPPLEMENTARY_TYPES'
      it_behaves_like 'includes measure type', 'THIRD_COUNTRY'
      it_behaves_like 'excludes measure type', 'THIRD_COUNTRY', 'FR'
      it_behaves_like 'excludes measure type', 'VAT_TYPES'
      it_behaves_like 'excludes measure type', 'VAT_TYPES', 'FR'
    end
  end

  describe '.with_regulation_dates_query' do
    subject { described_class.with_regulation_dates_query.all.first }

    around { |example| TimeMachine.now { example.run } }
    before { measure }

    shared_examples 'it has effective dates' do |regulation_type|
      let :regulation do
        create regulation_type, validity_start_date: 3.days.ago.beginning_of_day,
                                validity_end_date: 10.days.from_now.end_of_day
      end

      let :measure do
        create :measure, generating_regulation: regulation,
                         validity_start_date: nil,
                         validity_end_date: nil
      end

      context 'with dates on measure' do
        let :measure do
          create :measure, generating_regulation: regulation,
                           validity_start_date: 5.days.ago.beginning_of_day,
                           validity_end_date: 3.days.from_now.end_of_day
        end

        it { is_expected.to have_attributes effective_start_date: 5.days.ago.beginning_of_day }
        it { is_expected.to have_attributes effective_end_date: 3.days.from_now.end_of_day.floor(6) }
      end

      context 'with effective dates on regulation' do
        let :regulation do
          create regulation_type, validity_start_date: 3.days.ago.beginning_of_day,
                                  validity_end_date: 10.days.from_now.end_of_day.floor(6),
                                  effective_end_date: 12.days.from_now.end_of_day.floor(6)
        end

        it { is_expected.to have_attributes effective_start_date: 3.days.ago.beginning_of_day }
        it { is_expected.to have_attributes effective_end_date: 12.days.from_now.end_of_day.floor(6) }
      end

      context 'with validity dates on regulation' do
        it { is_expected.to have_attributes effective_start_date: 3.days.ago.beginning_of_day }
        it { is_expected.to have_attributes effective_end_date: 10.days.from_now.end_of_day.floor(6) }
      end

      context 'with no dates at all' do
        let :regulation do
          create regulation_type, validity_start_date: nil,
                                  validity_end_date: nil
        end

        it { is_expected.to be_nil }
      end

      context 'without an approved generating regulation' do
        let(:measure) { create :measure, generating_regulation: regulation }
        let(:regulation) { create regulation_type, :unapproved }

        it { is_expected.to be_nil }
      end
    end

    it_behaves_like 'it has effective dates', :base_regulation
    it_behaves_like 'it has effective dates', :modification_regulation

    context 'without base_regulation or modification_regulation' do
      let :measure do
        create :measure, measure_generating_regulation_id: nil,
                         measure_generating_regulation_role: nil
      end

      it { is_expected.to be_nil }
    end
  end

  describe '.dedupe_similar' do
    subject :measures do
      described_class.dedupe_similar.with_regulation_dates_query.all
    end

    before { first && second }

    let :first do
      create :measure, generating_regulation:,
                       validity_start_date: 3.days.ago.beginning_of_day
    end

    let :second do
      create :measure, generating_regulation:,
                       validity_start_date: 7.days.ago.beginning_of_day
    end

    let(:generating_regulation) { create :base_regulation }

    context 'with unmatched measures' do
      it { is_expected.to eq_pk [second, first] }
    end

    context 'with matching measures' do
      let :second do
        create :measure,
               first.values
                    .without(:measure_sid)
                    .merge(validity_start_date: 20.days.ago.beginning_of_day)
      end

      it 'includes only the most recent' do
        expect(measures).to eq_pk [first]
      end
    end
  end

  describe '#goods_nomenclature' do
    around { |example| TimeMachine.now { example.run } }

    context 'when the goods nomenclature is active' do
      subject(:goods_nomenclature) { create(:measure, :with_goods_nomenclature).goods_nomenclature }

      it { is_expected.to be_present }
    end

    context 'when the goods nomenclature is inactive' do
      subject(:goods_nomenclature) { create(:measure, :with_inactive_goods_nomenclature).goods_nomenclature }

      it { is_expected.not_to be_present }
    end
  end

  describe '#generating_regulation' do
    context 'when the measure is generated by a base regulation' do
      let(:measure) { create :measure }

      it { expect(measure.generating_regulation).to eq measure.base_regulation }
    end

    context 'when the measure is generated by a modification regulation' do
      let(:measure) { create :measure, :with_modification_regulation }

      it { expect(measure.generating_regulation).to eq measure.modification_regulation }
    end
  end

  describe '#base_regulation' do
    context 'when base regulation approved_flag is set to true' do
      let(:measure) { create :measure, :with_base_regulation }

      it { expect(measure.base_regulation).to eq measure.base_regulation }
    end

    context 'when base regulation approved_flag is set to false' do
      let(:measure) { create :measure, :with_unapproved_base_regulation }

      it { expect(measure.base_regulation).to eq nil }
    end
  end

  describe '#modification_regulation' do
    context 'when modification regulation approved_flag is set to true' do
      let(:measure) { create :measure, :with_modification_regulation }

      it { expect(measure.modification_regulation).to eq measure.modification_regulation }
    end

    context 'when modification regulation approved_flag is set to false' do
      let(:measure) { create :measure, :with_unapproved_modification_regulation }

      it { expect(measure.modification_regulation).to eq nil }
    end
  end

  describe '#measures' do
    context 'with different dates and generating regulation types' do
      before do
        Sequel::Model.db.run(%{
        INSERT INTO measures_oplog (measure_sid, measure_type_id, geographical_area_id, goods_nomenclature_item_id, validity_start_date, validity_end_date, measure_generating_regulation_role, measure_generating_regulation_id, justification_regulation_role, justification_regulation_id, stopped_flag, geographical_area_sid, goods_nomenclature_sid, ordernumber, additional_code_type_id, additional_code_id, additional_code_sid, reduction_indicator, export_refund_nomenclature_sid, national, tariff_measure_number, invalidated_by, invalidated_at, oid, operation, operation_date)
        VALUES
        (3445395, '103', '1011', '0805201000', '2016-01-01 00:00:00', '2016-02-29 00:00:00', 4, 'R1517542', 4, 'R1517542', false, 400, 68304, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 3071870, 'U', '2015-11-26'),
        (3445396, '103', '1011', '0805201000', '2016-03-01 00:00:00', '2016-10-31 00:00:00', 4, 'R1517542', 4, 'R1517542', false, 400, 68304, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 3071871, 'U', '2015-11-26'),
        (3445397, '103', '1011', '0805201000', '2016-11-01 00:00:00', '2016-12-31 00:00:00', 4, 'R1517542', 4, 'R1517542', false, 400, 68304, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 3071872, 'U', '2015-11-26');
                             })
        Sequel::Model.db.run(%{
        INSERT INTO modification_regulations_oplog (modification_regulation_role, modification_regulation_id, validity_start_date, validity_end_date, published_date, officialjournal_number, officialjournal_page, base_regulation_role, base_regulation_id, replacement_indicator, stopped_flag, information_text, approved_flag, explicit_abrogation_regulation_role, explicit_abrogation_regulation_id, effective_end_date, complete_abrogation_regulation_role, complete_abrogation_regulation_id, oid, operation, operation_date)
        VALUES
        (4, 'R1517542', '2016-01-01 00:00:00', NULL, '2015-10-30', 'L 285', 1, 1, 'R8726580', 0, false, 'CN 2016 (Entry prices)', true, NULL, NULL, NULL, NULL, NULL, 26064, 'C', '2015-11-26');
                             })
        Sequel::Model.db.run(%{
        INSERT INTO goods_nomenclatures_oplog (goods_nomenclature_sid, goods_nomenclature_item_id, producline_suffix, validity_start_date, validity_end_date, statistical_indicator, created_at, oid, operation, operation_date)
        VALUES
        (68304, '0805201000', '80', '1998-01-01 00:00:00', NULL, 0, '2013-08-02 20:03:55', 37691, 'C', NULL),
        (70329, '0805201005', '80', '1999-01-01 00:00:00', NULL, 0, '2013-08-02 20:04:48', 39237, 'C', NULL);

        INSERT INTO goods_nomenclature_indents_oplog (goods_nomenclature_indent_sid, goods_nomenclature_sid, validity_start_date, number_indents, goods_nomenclature_item_id, productline_suffix, created_at, validity_end_date, oid, operation, operation_date)
        VALUES
        (67883, 68304, '1998-01-01 00:00:00', 2, '0805201000', '80', '2013-08-02 20:03:55', NULL, 38832, 'C', NULL),
        (69920, 70329, '1999-01-01 00:00:00', 3, '0805201005', '80', '2013-08-02 20:04:48', NULL, 40421, 'C', NULL);
                             })
      end

      it { expect(TimeMachine.no_time_machine { described_class.with_modification_regulations.all.count }).to eq 3 }
      it { expect(TimeMachine.no_time_machine { Commodity.by_code('0805201000').first.measures.count }).to eq 3 }
      it { expect(TimeMachine.at(Time.zone.parse('2016-07-21')) { described_class.with_modification_regulations.with_actual(ModificationRegulation).all.first.measure_sid }).to eq 3_445_396 }
      it { expect(TimeMachine.at(Time.zone.parse('2016-07-21')) { Commodity.by_code('0805201005').first.measures.count }).to eq 1 }
      it { expect(TimeMachine.at(Time.zone.parse('2016-07-21')) { Commodity.by_code('0805201005').first.measures.first.measure_sid }).to eq 3_445_396 }
    end
  end

  describe '#validity_end_date' do
    shared_examples 'a measure validity_end_date' do |national_measure, measure_end_date, base_regulation_end_date, expected_date|
      let(:measure) do
        create(
          :measure,
          measure_generating_regulation_role: Measure::BASE_REGULATION_ROLE,
          national: national_measure,
          base_regulation:,
          validity_end_date: measure_end_date,
        )
      end

      let(:base_regulation) { create(:base_regulation, effective_end_date: base_regulation_end_date) }

      it "returns #{expected_date}" do
        expect(measure.validity_end_date&.to_date).to eq expected_date
      end
    end

    # Non-national measure always prefers the measures end date but will use the base regulations end date if the measure end date is nil
    it_behaves_like 'a measure validity_end_date', false, nil, nil, nil
    it_behaves_like 'a measure validity_end_date', false, nil, Time.zone.tomorrow, Time.zone.tomorrow
    it_behaves_like 'a measure validity_end_date', false, Time.zone.today, nil, nil
    it_behaves_like 'a measure validity_end_date', false, Time.zone.today, Time.zone.tomorrow, Time.zone.today

    # National measure always returns the measures end date
    it_behaves_like 'a measure validity_end_date', true, nil, nil, nil
    it_behaves_like 'a measure validity_end_date', true, nil, Time.zone.tomorrow, nil
    it_behaves_like 'a measure validity_end_date', true, Time.zone.today, nil, Time.zone.today
    it_behaves_like 'a measure validity_end_date', true, Time.zone.today, Time.zone.tomorrow, Time.zone.today
  end

  describe 'associations' do
    describe 'measure type' do
      let!(:measure)         { create :measure }
      let!(:measure_type1)   do
        create :measure_type, measure_type_id: measure.measure_type_id,
                              validity_start_date: 5.years.ago,
                              validity_end_date: 3.years.ago,
                              operation_date: Time.zone.yesterday
      end

      before do
        create :measure_type, measure_type_id: measure.measure_type_id,
                              validity_start_date: 2.years.ago,
                              validity_end_date: nil,
                              operation: :update
      end

      context 'when direct loading' do
        it 'loads correct description respecting given actual time' do
          TimeMachine.now do
            expect(measure.measure_type.pk).to eq measure_type1.pk
          end
        end

        it 'loads correct description respecting given time' do
          TimeMachine.at(1.year.ago) do
            expect(measure.measure_type.pk).to eq measure_type1.pk
          end
        end
      end

      context 'when eager loading' do
        it 'loads correct description respecting given actual time' do
          TimeMachine.now do
            expect(
              described_class.where(measure_sid: measure.measure_sid)
                          .eager(:measure_type)
                          .all
                          .first
                          .measure_type.pk,
            ).to eq measure_type1.pk
          end
        end

        it 'loads correct description respecting given time' do
          TimeMachine.at(1.year.ago) do
            expect(
              described_class.where(measure_sid: measure.measure_sid)
                          .eager(:measure_type)
                          .all
                          .first
                          .measure_type.pk,
            ).to eq measure_type1.pk
          end
        end
      end
    end

    describe 'measure conditions' do
      let!(:measure)                { create :measure }
      let!(:measure_condition1)     { create :measure_condition, measure_sid: measure.measure_sid }
      let!(:measure_condition2)     { create :measure_condition }

      context 'when direct loading' do
        it 'loads associated measure conditions' do
          expect(measure.measure_conditions).to include measure_condition1
        end

        it 'does not load associated measure condition' do
          expect(measure.measure_conditions).not_to include measure_condition2
        end
      end

      context 'when eager loading' do
        it 'loads associated measure conditions' do
          expect(
            described_class.where(measure_sid: measure.measure_sid)
                 .eager(:measure_conditions)
                 .all
                 .first
                 .measure_conditions,
          ).to include measure_condition1
        end

        it 'does not load associated measure condition' do
          expect(
            described_class.where(measure_sid: measure.measure_sid)
                 .eager(:measure_conditions)
                 .all
                 .first
                 .measure_conditions,
          ).not_to include measure_condition2
        end
      end

      describe 'ordering' do
        let!(:measure)                { create :measure }
        let!(:measure_condition1)     { create :measure_condition, measure_sid: measure.measure_sid, condition_code: 'L', component_sequence_number: 10 }
        let!(:measure_condition2)     { create :measure_condition, measure_sid: measure.measure_sid, condition_code: 'A', component_sequence_number: 1 }

        it 'loads conditions ordered by component sequence number ascending' do
          expect(measure.measure_conditions).to eq [measure_condition2, measure_condition1]
        end
      end
    end

    describe 'geographical area' do
      let!(:geographical_area1)     { create :geographical_area, geographical_area_id: 'ab' }
      let!(:geographical_area2)     { create :geographical_area, geographical_area_id: 'de' }
      let!(:measure)                { create :measure, geographical_area_sid: geographical_area1.geographical_area_sid }

      context 'when direct loading' do
        it 'loads associated measure conditions' do
          expect(measure.geographical_area.pk).to eq geographical_area1.pk
        end

        it 'does not load associated measure condition' do
          expect(measure.geographical_area.pk).not_to eq geographical_area2.pk
        end
      end

      context 'when eager loading' do
        it 'loads associated measure conditions' do
          expect(
            described_class.where(measure_sid: measure.measure_sid)
                 .eager(:geographical_area)
                 .all
                 .first
                 .geographical_area.pk,
          ).to eq geographical_area1.pk
        end

        it 'does not load associated measure condition' do
          expect(
            described_class.where(measure_sid: measure.measure_sid)
                 .eager(:geographical_area)
                 .all
                 .first
                 .geographical_area.pk,
          ).not_to eq geographical_area2.pk
        end
      end
    end

    describe 'footnotes' do
      let!(:measure)          { create :measure }
      let!(:footnote1)        do
        create :footnote, validity_start_date: 2.years.ago,
                          validity_end_date: nil
      end
      let!(:footnote2) do
        create :footnote, validity_start_date: 5.years.ago,
                          validity_end_date: 3.years.ago
      end

      before do
        create :footnote_association_measure, measure_sid: measure.measure_sid,
                                              footnote_id: footnote1.footnote_id,
                                              footnote_type_id: footnote1.footnote_type_id
        create :footnote_association_measure, measure_sid: measure.measure_sid,
                                              footnote_id: footnote2.footnote_id,
                                              footnote_type_id: footnote2.footnote_type_id
      end

      context 'when direct loading' do
        it 'loads correct indent respecting given actual time' do
          TimeMachine.now do
            expect(
              measure.footnotes.map(&:pk),
            ).to include footnote1.pk
          end
        end

        it 'loads correct indent respecting given time' do
          TimeMachine.at(4.years.ago) do
            expect(
              measure.reload.footnotes.map(&:pk),
            ).to include footnote2.pk
          end
        end
      end

      describe 'order' do
        it 'loads items in alphabetical order by footnote_type_id asc' do
          TimeMachine.now do
            f1 = create(:footnote, validity_start_date: 2.years.ago, footnote_type_id: '02')
            create(:footnote_association_measure, measure_sid: measure.measure_sid,
                                                  footnote_id: f1.footnote_id,
                                                  footnote_type_id: f1.footnote_type_id)
            f2 = create(:footnote, validity_start_date: 2.years.ago, footnote_type_id: '00')
            create(:footnote_association_measure, measure_sid: measure.measure_sid,
                                                  footnote_id: f2.footnote_id,
                                                  footnote_type_id: f2.footnote_type_id)
            expect(measure.reload.footnotes.first).to eq(f2)
          end
        end

        it 'loads items in alphabetical order by footnote_id asc' do
          TimeMachine.now do
            f1 = create(:footnote, validity_start_date: 2.years.ago, footnote_type_id: '02', footnote_id: '123')
            create(:footnote_association_measure, measure_sid: measure.measure_sid,
                                                  footnote_id: f1.footnote_id,
                                                  footnote_type_id: f1.footnote_type_id)
            f2 = create(:footnote, validity_start_date: 2.years.ago, footnote_type_id: '02', footnote_id: '124')
            create(:footnote_association_measure, measure_sid: measure.measure_sid,
                                                  footnote_id: f2.footnote_id,
                                                  footnote_type_id: f2.footnote_type_id)
            expect(measure.reload.footnotes.first).to eq(f1)
          end
        end
      end

      context 'when eager loading' do
        it 'loads correct indent respecting given actual time' do
          TimeMachine.now do
            expect(
              described_class.where(measure_sid: measure.measure_sid)
                          .eager(:footnotes)
                          .all
                          .first
                          .footnotes.map(&:pk),
            ).to include footnote1.pk
          end
        end

        it 'loads correct indent respecting given time' do
          TimeMachine.at(4.years.ago) do
            expect(
              described_class.where(measure_sid: measure.measure_sid)
                          .eager(:footnotes)
                          .all
                          .first
                          .footnotes.map(&:pk),
            ).to include footnote2.pk
          end
        end
      end
    end

    describe 'measure components' do
      let!(:measure)                { create :measure }
      let!(:measure_component1)     { create :measure_component, measure_sid: measure.measure_sid, duty_expression_id: '03' }
      let!(:measure_component2)     { create :measure_component }

      before do
        create :measure_component, measure_sid: measure.measure_sid, duty_expression_id: '01'
      end

      context 'when direct loading' do
        it 'loads associated measure components' do
          expect(measure.measure_components).to include measure_component1
        end

        it 'does not load associated measure component' do
          expect(measure.measure_components).not_to include measure_component2
        end

        it 'orders components by duty_expression_id' do
          expect(measure.measure_components.pluck(:duty_expression_id)).to eq(%w[01 03])
        end
      end

      context 'when eager loading' do
        it 'loads associated measure components' do
          expect(
            described_class.where(measure_sid: measure.measure_sid)
                 .eager(:measure_components)
                 .all
                 .first
                 .measure_components,
          ).to include measure_component1
        end

        it 'does not load associated measure component' do
          expect(
            described_class.where(measure_sid: measure.measure_sid)
                 .eager(:measure_components)
                 .all
                 .first
                 .measure_components,
          ).not_to include measure_component2
        end
      end
    end

    describe 'additional code' do
      let!(:additional_code1)     { create :additional_code, validity_start_date: 3.years.ago.beginning_of_day }
      let!(:additional_code2)     { create :additional_code, validity_start_date: 5.years.ago.beginning_of_day }
      let!(:measure)              { create :measure, additional_code_sid: additional_code1.additional_code_sid }

      context 'when direct loading' do
        it 'loads associated measure conditions' do
          expect(measure.additional_code).to eq additional_code1
        end

        it 'does not load associated measure condition' do
          expect(measure.additional_code).not_to eq additional_code2
        end
      end

      context 'when eager loading' do
        it 'loads associated measure conditions' do
          expect(
            described_class.where(measure_sid: measure.measure_sid)
                 .eager(:additional_code)
                 .all
                 .first
                 .additional_code,
          ).to eq additional_code1
        end

        it 'does not load associated measure condition' do
          expect(
            described_class.where(measure_sid: measure.measure_sid)
                 .eager(:additional_code)
                 .all
                 .first
                 .additional_code,
          ).not_to eq additional_code2
        end
      end
    end

    describe 'quota order number' do
      let!(:quota_order_number1)     { create :quota_order_number, validity_start_date: 3.years.ago.beginning_of_day }
      let!(:quota_order_number2)     { create :quota_order_number, validity_start_date: 5.years.ago.beginning_of_day }
      let!(:measure)                 { create :measure, ordernumber: quota_order_number1.quota_order_number_id }

      context 'when direct loading' do
        it 'loads associated measure conditions' do
          expect(measure.quota_order_number).to eq quota_order_number1
        end

        it 'does not load associated measure condition' do
          expect(measure.quota_order_number).not_to eq quota_order_number2
        end
      end

      context 'when eager loading' do
        it 'loads associated measure conditions' do
          expect(
            described_class.where(measure_sid: measure.measure_sid)
                 .eager(:quota_order_number)
                 .all
                 .first
                 .quota_order_number,
          ).to eq quota_order_number1
        end

        it 'does not load associated measure condition' do
          expect(
            described_class.where(measure_sid: measure.measure_sid)
                 .eager(:quota_order_number)
                 .all
                 .first
                 .quota_order_number,
          ).not_to eq quota_order_number2
        end
      end
    end

    describe 'full temporary stop regulation' do
      let!(:measure)                { create :measure, measure_generating_regulation_id: fts_regulation_action1.stopped_regulation_id }
      let!(:fts_regulation1)        { create :fts_regulation, validity_start_date: 3.years.ago.beginning_of_day }
      let!(:fts_regulation2)        { create :fts_regulation, validity_start_date: 5.years.ago.beginning_of_day }
      let!(:fts_regulation_action1) { create :fts_regulation_action, fts_regulation_id: fts_regulation1.full_temporary_stop_regulation_id }

      before do
        create :fts_regulation_action, fts_regulation_id: fts_regulation2.full_temporary_stop_regulation_id
      end

      context 'when direct loading' do
        it 'loads associated full temporary stop regulation' do
          expect(measure.full_temporary_stop_regulation.pk).to eq fts_regulation1.pk
        end

        it 'does not load associated full temporary stop regulation' do
          expect(measure.full_temporary_stop_regulation.pk).not_to eq fts_regulation2.pk
        end
      end

      context 'when eager loading' do
        it 'loads associated full temporary stop regulation' do
          expect(
            described_class.where(measure_sid: measure.measure_sid)
                 .eager(:full_temporary_stop_regulations)
                 .all
                 .first
                 .full_temporary_stop_regulation.pk,
          ).to eq fts_regulation1.pk
        end

        it 'does not load associated full temporary stop regulation' do
          expect(
            described_class.where(measure_sid: measure.measure_sid)
                 .eager(:full_temporary_stop_regulations)
                 .all
                 .first
                 .full_temporary_stop_regulation.pk,
          ).not_to eq fts_regulation2.pk
        end
      end
    end

    describe 'measure partial temporary stop' do
      let!(:mpt_stop1)        { create :measure_partial_temporary_stop, validity_start_date: 3.years.ago.beginning_of_day }
      let!(:mpt_stop2)        { create :measure_partial_temporary_stop, validity_start_date: 5.years.ago.beginning_of_day }
      let!(:measure)          { create :measure, measure_generating_regulation_id: mpt_stop1.partial_temporary_stop_regulation_id, measure_sid: mpt_stop1.measure_sid }

      context 'when direct loading' do
        it 'loads associated full temporary stop regulation' do
          expect(measure.measure_partial_temporary_stop.pk).to eq mpt_stop1.pk
        end

        it 'does not load associated full temporary stop regulation' do
          expect(measure.measure_partial_temporary_stop.pk).not_to eq mpt_stop2.pk
        end
      end

      context 'when eager loading' do
        it 'loads associated full temporary stop regulation' do
          expect(
            described_class.where(measure_sid: measure.measure_sid)
                 .eager(:measure_partial_temporary_stops)
                 .all
                 .first
                 .measure_partial_temporary_stop.pk,
          ).to eq mpt_stop1.pk
        end

        it 'does not load associated full temporary stop regulation' do
          expect(
            described_class.where(measure_sid: measure.measure_sid)
                 .eager(:measure_partial_temporary_stops)
                 .all
                 .first
                 .measure_partial_temporary_stop.pk,
          ).not_to eq mpt_stop2.pk
        end
      end
    end
  end

  describe '#origin' do
    subject(:origin) { build(:measure, measure_sid:).origin }

    before { described_class.unrestrict_primary_key }

    context 'when the measure sid is negative' do
      let(:measure_sid) { -1 }

      it { is_expected.to eq 'uk' }
    end

    context 'when the measure sid is positive' do
      let(:measure_sid) { 1 }

      it { is_expected.to eq 'eu' }
    end

    context 'when the measure sid is zero' do
      let(:measure_sid) { 0 }

      it { is_expected.to eq 'eu' }
    end

    context 'when the measure sid is nil' do
      let(:measure_sid) { nil }

      it { expect { origin }.to raise_error(Sequel::Error) }
    end
  end

  describe '#order_number' do
    context 'when a quota_order_number is associated' do
      let(:quota_order_number) { create :quota_order_number }
      let(:measure) { create :measure, ordernumber: quota_order_number.quota_order_number_id }

      it 'returns associated quota order nmber' do
        expect(measure.order_number).to eq quota_order_number
      end
    end

    context 'when a quota_order_number is not associated' do
      let(:ordernumber) { 6.times.map { Random.rand(9) }.join }
      let(:measure) { create :measure, ordernumber: }

      it 'returns a mock quota order number with just the number set' do
        expect(measure.order_number.quota_order_number_id).to eq ordernumber
      end

      it 'associated mock quota order number should have no quota definition' do
        expect(measure.order_number.quota_definition).to be_blank
      end
    end
  end

  describe '#import' do
    let(:measure) { create :measure, measure_type: }

    context 'when the measure type is import' do
      let(:measure_type) { create :measure_type, :import }

      it { expect(measure.import).to eq(true) }
    end

    context 'when the measure type is export' do
      let(:measure_type) { create :measure_type, :export }

      it { expect(measure.import).to eq(false) }
    end
  end

  describe '#export' do
    let(:measure) { create :measure, measure_type: }

    context 'when the measure type is import' do
      let(:measure_type) { create :measure_type, :import }

      it { expect(measure.import).to be_truthy }
      it { expect(measure.export).to be_falsy }
    end

    context 'when the measure type is export' do
      let(:measure_type) { create :measure_type, :export }

      it { expect(measure.import).to be_falsy }
      it { expect(measure.export).to be_truthy }
    end

    context 'when the measure type is import and export' do
      let(:measure_type) { create :measure_type, :import_and_export }

      it { expect(measure.import).to be_truthy }
      it { expect(measure.export).to be_truthy }
    end
  end

  describe '#meursing?' do
    let(:measure) { create :measure }

    context 'when measure components are meursing' do
      before do
        create :measure_component,
               measure_sid: measure.measure_sid,
               duty_expression_id: DutyExpression::MEURSING_DUTY_EXPRESSION_IDS.sample
      end

      it { expect(measure).to be_meursing }
    end

    context 'when measure components are not meursing' do
      before do
        create :measure_component,
               measure_sid: measure.measure_sid,
               duty_expression_id: 'aaa'
      end

      it { expect(measure).not_to be_meursing }
    end
  end

  describe '.changes_for' do
    subject(:changes_for) do
      TimeMachine.at(requested_date) do
        described_class.changes_for
      end
    end

    let(:measure) { create :measure, validity_start_date: measure_validity_start_date, operation_date: Date.new(2014, 2, 1) }

    before { measure }

    context 'when measure validity start date is after the requested date' do
      let(:requested_date) { Date.new(2014, 1, 30) }
      let(:measure_validity_start_date) { Date.new(2014, 2, 1) }

      it { expect(changes_for).to be_empty }
    end

    context 'when measure validity start date is on the requested date' do
      let(:requested_date) { Date.new(2014, 2, 1) }
      let(:measure_validity_start_date) { Date.new(2014, 2, 1) }

      it { expect(changes_for.map(&:oid)).to eq([measure.oid]) }
    end

    context 'when measure validity start date is before the requested date' do
      let(:requested_date) { Date.new(2014, 2, 2) }
      let(:measure_validity_start_date) { Date.new(2014, 2, 1) }

      it { expect(changes_for.map(&:oid)).to eq([measure.oid]) }
    end

    context 'when there are multiple measures and one has no operation date' do
      let(:requested_date) { Date.new(2014, 2, 1) }
      let(:measure_validity_start_date) { Date.new(2014, 2, 1) }

      before do
        create :measure, validity_start_date: measure_validity_start_date, operation_date: nil
      end

      it { expect(changes_for.map(&:operation_date)).to eq([Date.new(2014, 2, 1), nil]) }
    end
  end

  describe '#relevant_for_country?' do
    context 'when the measure excludes the country id' do
      subject(:measure) { create(:measure, :with_measure_excluded_geographical_area) }

      let(:country) { measure.measure_excluded_geographical_areas.first.geographical_area }

      it { expect(measure.relevant_for_country?(country.geographical_area_id)).to eq(false) }
    end

    context 'when the measure excludes a group the country belongs to' do
      subject(:measure) { create(:measure, :with_measure_excluded_geographical_area_group) }

      let(:country) do
        measure
          .measure_excluded_geographical_areas
          .first
          .geographical_area
          .contained_geographical_areas
          .first
      end

      it { expect(measure.relevant_for_country?(country.geographical_area_id)).to eq(false) }
    end

    context 'when the measure excludes a referenced group the country belongs to' do
      subject(:measure) { create(:measure, :with_measure_excluded_geographical_area_referenced_group) }

      let(:country) do
        measure
          .measure_excluded_geographical_areas
          .first
          .geographical_area
      end

      it { expect(measure.relevant_for_country?(country.geographical_area_id)).to eq(false) }
    end

    context 'when the measure is a national measure and its geographical area is the world' do
      subject(:measure) { create(:measure, :national, geographical_area_id: '1011') }

      let(:country) { build(:geographical_area) }

      it { expect(measure.relevant_for_country?(country.geographical_area_id)).to eq(true) }
    end

    context 'when the measure has a meursing measure type and its geographical area is the world' do
      subject(:measure) { create(:measure, :flour, geographical_area_id: '1011') }

      let(:country) { build(:geographical_area) }

      it { expect(measure.relevant_for_country?(country.geographical_area_id)).to eq(true) }
    end

    context 'when the measure has no geographical area' do
      subject(:measure) { create(:measure, geographical_area_sid: nil, geographical_area_id: nil) }

      let(:country) { build(:geographical_area) }

      it { expect(measure.relevant_for_country?(country.geographical_area_id)).to eq(true) }
    end

    context 'when the measure has a geographical area that is the country' do
      subject(:measure) { create(:measure) }

      let(:country) { measure.geographical_area }

      it { expect(measure.relevant_for_country?(country.geographical_area_id)).to eq(true) }
    end

    context 'when the measure has a contained geographical area that is the country' do
      subject(:measure) { create(:measure, geographical_area_sid: geographical_area.geographical_area_sid) }

      let(:geographical_area) { create(:geographical_area, :group) }
      let(:contained_geographical_area) { create(:geographical_area, :country) }

      before do
        create(
          :geographical_area_membership,
          geographical_area_sid: contained_geographical_area.geographical_area_sid,
          geographical_area_group_sid: geographical_area.geographical_area_sid,
        )
      end

      it { expect(measure.relevant_for_country?(contained_geographical_area.geographical_area_id)).to eq(true) }
    end

    context 'when the measure has a referenced contained geographical area that is the country' do
      subject(:measure) { create(:measure, geographical_area_sid: geographical_area.geographical_area_sid, geographical_area_id: 'EU') }

      let(:geographical_area) { create(:geographical_area, :with_reference_group_and_members, geographical_area_id: 'EU') }

      it { expect(measure.relevant_for_country?('FR')).to eq(true) }
    end
  end

  describe '#expresses_unit?' do
    context 'when the measure type is one that expresses the unit' do
      context 'when the measure has measure components with units' do
        subject(:measure) { create(:measure, :with_measure_components, :no_ad_valorem, :expresses_units) }

        it { expect(measure).to be_expresses_unit }
      end

      context 'when the measure has measure conditions with units' do
        subject(:measure) { create(:measure, :with_measure_conditions, :no_ad_valorem, :expresses_units) }

        it { expect(measure).to be_expresses_unit }
      end

      context 'when the measure has resolved measure components with units' do
        subject(:measure) { create(:measure, :expresses_units) }

        before do
          measure_unit_component = create(
            :measure_component,
            :with_measure_unit,
            measure_sid: measure.measure_sid,
          )
          allow(MeursingMeasureFinderService).to receive(:new).and_return(instance_double('MeursingMeasureFinderService', call: []))
          allow(MeursingMeasureComponentResolverService).to receive(:new).and_return(instance_double('MeursingMeasureComponentResolverService', call: [measure_unit_component]))
        end

        it { expect(measure).to be_expresses_unit }
      end
    end

    context 'when the measure type is one that does not express units' do
      subject(:measure) { create(:measure, :with_measure_components, :no_expresses_units) }

      it { expect(measure).not_to be_expresses_unit }
    end
  end

  describe '#ad_valorem?' do
    context 'when there are ad valorem conditions' do
      subject(:measure) { create(:measure, :with_measure_conditions, :ad_valorem) }

      it { expect(measure).to be_ad_valorem }
    end

    context 'when there are ad valorem components' do
      subject(:measure) { create(:measure, :with_measure_components, :ad_valorem) }

      it { expect(measure).to be_ad_valorem }
    end

    context 'when there are ad valorem resolved components' do
      subject(:measure) { create(:measure) }

      before do
        ad_valorem_component = create(
          :measure_component,
          :ad_valorem,
          :with_duty_expression,
          duty_amount: 28,
          measure_sid: measure.measure_sid,
        )
        allow(MeursingMeasureFinderService).to receive(:new).and_return(instance_double('MeursingMeasureFinderService', call: []))
        allow(MeursingMeasureComponentResolverService).to receive(:new).and_return(
          instance_double(
            'MeursingMeasureComponentResolverService',
            call: [ad_valorem_component],
          ),
        )
      end

      it { expect(measure).to be_ad_valorem }
    end

    context 'when there are no ad valorem conditions or components' do
      subject(:measure) { create(:measure, :with_measure_components, :with_measure_conditions, :no_ad_valorem) }

      it { expect(measure).not_to be_ad_valorem }
    end
  end

  describe '#zero_mfn?' do
    context 'when the measure type is a third country' do
      subject(:measure) do
        create(
          :measure,
          :third_country,
          :with_measure_components,
          duty_amount:,
        )
      end

      context 'when measure components have zero duty amount' do
        let(:duty_amount) { 0.0 }

        it 'returns true' do
          expect(measure).to be_zero_mfn
        end

        context 'when there are more than one measure components' do
          before do
            create(
              :measure_component,
              measure_sid: measure.measure_sid,
              duty_amount:,
              duty_expression_id: '01',
            )
          end

          it 'returns false' do
            expect(measure).not_to be_zero_mfn
          end
        end
      end

      context 'when measure components have a non zero duty amount' do
        let(:duty_amount) { 67.45 }

        it 'returns false when measure components have non zero duty amount' do
          expect(measure).not_to be_zero_mfn
        end
      end

      context 'when measure components have a nil duty amount' do
        let(:duty_amount) { nil }

        it 'returns false when measure components have non zero duty amount' do
          expect(measure).not_to be_zero_mfn
        end
      end
    end

    context 'when the measure type is not a third country' do
      subject(:measure) { create(:measure, measure_type_id: 'foo') }

      it 'returns false' do
        expect(measure).not_to be_zero_mfn
      end
    end
  end

  describe '#units' do
    context 'when there are measure components and measure components' do
      subject(:measure) { create(:measure, :with_measure_components, :with_measure_conditions) }

      let(:expected_units) do
        [
          {
            measurement_unit_code: 'DTN',
            measurement_unit_qualifier_code: 'R',
          },
          {
            measurement_unit_code: 'DTN',
            measurement_unit_qualifier_code: 'R',
          },
        ]
      end

      it 'returns the units' do
        expect(measure.units).to eq(expected_units)
      end
    end

    context 'when there are measure components' do
      subject(:measure) { create(:measure, :with_measure_components) }

      let(:expected_units) do
        [
          {
            measurement_unit_code: 'DTN',
            measurement_unit_qualifier_code: 'R',
          },
        ]
      end

      it 'returns the units' do
        expect(measure.units).to eq(expected_units)
      end
    end

    context 'when there are measure conditions' do
      subject(:measure) { create(:measure, :with_measure_conditions) }

      let(:expected_units) do
        [
          {
            measurement_unit_code: 'DTN',
            measurement_unit_qualifier_code: 'R',
          },
        ]
      end

      it 'returns the units' do
        expect(measure.units).to eq(expected_units)
      end
    end

    context 'when there are no measure conditions or components' do
      subject(:measure) { create(:measure) }

      it 'returns the units' do
        expect(measure.units).to eq([])
      end
    end
  end

  describe '#resolved_measure_components' do
    subject(:measure) { create(:measure) }

    before do
      allow(MeursingMeasureFinderService).to receive(:new).and_return(instance_double('MeursingMeasureFinderService', call: meursing_measures))
      allow(MeursingMeasureComponentResolverService).to receive(:new).and_return(instance_double('MeursingMeasureComponentResolverService', call: resolved_components))
    end

    include_context 'with meursing additional code id', '000'

    let(:meursing_measures) { [build(:measure)] }
    let(:resolved_components) { [] }

    let(:ad_valorem_component) do
      create(
        :measure_component,
        :ad_valorem,
        :with_duty_expression,
        duty_amount: 28,
        measure_sid: measure.measure_sid,
      )
    end

    let(:agricultural_component) do
      Api::V2::Measures::MeursingMeasureComponentPresenter.new(
        create(
          :measure_component,
          :agricultural_meursing,
          :with_duty_expression,
          duty_amount: 100,
          measurement_unit_code: 'DTN',
          monetary_unit_code: 'EUR',
          measure_sid: measure.measure_sid,
        ),
      )
    end

    context 'when the measure is not meursing' do
      subject(:measure) { create(:measure, :with_measure_components, :without_meursing) }

      it { expect(measure.resolved_measure_components).to eq([]) }
    end

    context 'when no resolved components are returned' do
      subject(:measure) { create(:measure, :with_measure_components, :with_meursing) }

      let(:resolved_components) { [] }

      it { expect(measure.resolved_measure_components).to eq([]) }
    end

    context 'when all of the resolved components are valid components' do
      subject(:measure) { create(:measure, :with_measure_components, :with_meursing) }

      let(:resolved_components) { [ad_valorem_component, agricultural_component] }

      it { expect(measure.resolved_measure_components).to eq(resolved_components) }
    end

    context 'when there are no meursing measures for our additional code' do
      subject(:measure) { create(:measure, :with_measure_components, :with_meursing) }

      let(:meursing_measures) { [] }

      it { expect(measure.resolved_measure_components).to eq([]) }
    end
  end

  describe '#resolved_duty_expression' do
    subject(:measure) { create(:measure) }

    include_context 'with meursing additional code id', '000'

    before do
      allow(MeursingMeasureFinderService).to receive(:new).and_return(instance_double('MeursingMeasureFinderService', call: meursing_measures))
      allow(MeursingMeasureComponentResolverService).to receive(:new).and_return(instance_double('MeursingMeasureComponentResolverService', call: resolved_components))
    end

    let(:meursing_measures) { [build(:measure)] }
    let(:resolved_components) { [] }

    let(:ad_valorem_component) do
      create(
        :measure_component,
        :ad_valorem,
        :with_duty_expression,
        duty_amount: 28,
        measure_sid: measure.measure_sid,
      )
    end

    let(:agricultural_component) do
      Api::V2::Measures::MeursingMeasureComponentPresenter.new(
        create(
          :measure_component,
          :agricultural_meursing,
          :with_duty_expression,
          duty_amount: 100,
          measurement_unit_code: 'DTN',
          monetary_unit_code: 'EUR',
          measure_sid: measure.measure_sid,
        ),
      )
    end

    context 'when the measure is not meursing' do
      subject(:measure) { create(:measure, :with_measure_components, :without_meursing) }

      it { expect(measure.resolved_duty_expression).to eq('') }
    end

    context 'when no resolved components are returned' do
      subject(:measure) { create(:measure, :with_measure_components, :with_meursing) }

      let(:resolved_components) { [] }

      it { expect(measure.resolved_duty_expression).to eq('') }
    end

    context 'when all of the resolved components are valid components' do
      subject(:measure) { create(:measure, :with_measure_components, :with_meursing) }

      let(:resolved_components) { [ad_valorem_component, agricultural_component] }

      it { expect(measure.resolved_duty_expression).to eq("<span>28.00</span> #{ad_valorem_component.duty_expression_description} <strong>+ <span>100.00</span> EUR</strong>") }
    end

    context 'when there are no meursing measures for our additional code' do
      subject(:measure) { create(:measure, :with_measure_components, :with_meursing) }

      let(:meursing_measures) { [] }

      it { expect(measure.resolved_duty_expression).to eq('') }
    end

    context 'when the additional_code_id is nil' do
      subject(:measure) { create(:measure, :with_measure_components, :with_meursing) }

      include_context 'with meursing additional code id', nil

      let(:resolved_components) { [ad_valorem_component, agricultural_component] }

      it { expect(measure.resolved_duty_expression).to eq('') }
    end
  end

  describe '#meursing_measures' do
    subject(:measure) { create(:measure) }

    before { allow(MeursingMeasureFinderService).to receive(:new).and_return(finder_service) }

    include_context 'with meursing additional code id', '000'

    let(:meursing_measures) { [] }

    let(:finder_service) do
      instance_double(
        'MeursingMeasureFinderService',
        call: meursing_measures,
      )
    end

    it 'calls the MeursingMeasureFinderService with the correct inputs' do
      measure.meursing_measures

      expect(MeursingMeasureFinderService).to have_received(:new).with(measure, '000')
    end

    it { expect(measure.meursing_measures).to eq(meursing_measures) }
  end

  describe '#universal_waiver_applies?' do
    context 'when at least one measure condition has the cds waiver document code' do
      subject(:measure) { create(:measure, :with_measure_conditions, certificate_type_code: '9', certificate_code: '99L') }

      it { is_expected.to be_universal_waiver_applies }
    end

    context 'when no measure conditions have the cds waiver document code' do
      subject(:measure) { create(:measure, :with_measure_conditions, certificate_type_code: '7', certificate_code: '97L') }

      it { is_expected.not_to be_universal_waiver_applies }
    end

    context 'when there are no measure conditions' do
      subject(:measure) { create(:measure) }

      it { is_expected.not_to be_universal_waiver_applies }
    end
  end

  shared_context 'with regulation measures' do
    around do |example|
      TimeMachine.now { example.run }
    end

    before do
      non_distinct_measure_opts = {
        goods_nomenclature_sid: 1,
        geographical_area_id: 'GB',
        geographical_area_sid: 1,
        measure_type_id: 1,
        measure_generating_regulation_id: 'R9726580',
        additional_code_type_id: 'F',
        additional_code_id: '001',
      }

      # Base regulation measures
      create(:measure, { measure_sid: 1, measure_generating_regulation_role: 1 }.merge(non_distinct_measure_opts))
      create(:measure, { measure_sid: 2, measure_generating_regulation_role: 2 }.merge(non_distinct_measure_opts))
      create(:measure, { measure_sid: 3, measure_generating_regulation_role: 3 }.merge(non_distinct_measure_opts))

      # Modification regulation measure
      create(:measure, measure_sid: 4, measure_generating_regulation_role: 4, measure_generating_regulation_id: 'R9726580')

      # No regulation measure - control - this is not possible in the wild even
      create(:measure, measure_sid: 5)
    end
  end

  describe '.with_base_regulations' do
    context 'when approved_flag is set to true' do
      subject(:with_base_regulations) { described_class.with_base_regulations.pluck(:measure_sid) }

      before do
        create(:base_regulation, base_regulation_id: 'R9726580', base_regulation_role: 1)
        create(:base_regulation, base_regulation_id: 'R9726580', base_regulation_role: 2)
        create(:base_regulation, base_regulation_id: 'R9726580', base_regulation_role: 3)
      end

      include_context 'with regulation measures'

      it { is_expected.to eq([1, 2, 3]) } # Base regulation measures
    end

    context 'when approved_flag is set to false' do
      subject(:with_base_regulations) { described_class.with_base_regulations.pluck(:measure_sid) }

      before do
        create(:base_regulation, :unapproved, base_regulation_id: 'R9726580', base_regulation_role: 1)
        create(:base_regulation, :unapproved, base_regulation_id: 'R9726580', base_regulation_role: 2)
        create(:base_regulation, :unapproved, base_regulation_id: 'R9726580', base_regulation_role: 3)
      end

      include_context 'with regulation measures'

      it { is_expected.to eq([]) } # Base regulation measures
    end
  end

  describe '.with_modification_regulations' do
    context 'when approved_flag is set to true' do
      subject(:with_modification_regulations) { described_class.with_modification_regulations.pluck(:measure_sid) }

      before { create(:modification_regulation, modification_regulation_id: 'R9726580') }

      include_context 'with regulation measures'

      it { is_expected.to eq([4]) } # Modification regulation measure
    end

    context 'when approved_flag is set to false' do
      subject(:with_modification_regulations) { described_class.with_modification_regulations.pluck(:measure_sid) }

      before { create(:modification_regulation, :unapproved, modification_regulation_id: 'R9726580') }

      include_context 'with regulation measures'

      it { is_expected.to eq([]) } # Modification regulation measure
    end
  end

  describe '#prettify_generated_duty_expression' do
    subject(:measure) { create(:measure).prettify_generated_duty_expression(duty_expression) }

    context 'when there are multiple spaces in the duty expression' do
      let(:duty_expression) { '100 with  multiple space  in it' }

      it { is_expected.to eq '100 with multiple space in it' }
    end

    context 'when there are simple expressed ad valorem percentages' do
      let(:duty_expression) { '100 %' }

      it { is_expected.to eq '100%' }
    end
  end

  describe '#sort_key' do
    subject { measure.sort_key }

    let :measure do
      create :measure,
             :with_additional_code,
             :with_additional_code_type,
             geographical_area_id: 'FR',
             ordernumber: '10',
             validity_end_date:
    end

    context 'with end date' do
      let(:validity_end_date) { 10.days.from_now.end_of_day }

      let :sort_key do
        [
          'FR',
          measure.measure_type_id,
          measure.additional_code_type_id,
          measure.additional_code_id,
          '10',
          measure.values[:validity_end_date],
        ]
      end

      it { is_expected.to eq sort_key }
    end

    context 'without end date' do
      let(:validity_end_date) { nil }

      let :sort_key do
        [
          'FR',
          measure.measure_type_id,
          measure.additional_code_type_id,
          measure.additional_code_id,
          '10',
          nil,
        ]
      end

      it { is_expected.to eq sort_key }
    end
  end

  describe '#<=>' do
    subject(:sorted) { [first, second, third].sort }

    let(:first) { build :measure, geographical_area_id: 'FR', measure_type_id: 2 }
    let(:second) { build :measure, geographical_area_id: 'ES', measure_type_id: 1 }
    let(:third) { build :measure, geographical_area_id: 'ES', measure_type_id: 2 }

    it { is_expected.to eq [second, third, first] }

    context 'with nil values on one side of comparison' do
      let(:second) { build :measure, geographical_area_id: nil, measure_type_id: 1 }

      it { is_expected.to eq [third, first, second] }
    end

    context 'with nils on both sides of comparison' do
      let(:first) { build :measure, geographical_area_id: nil, measure_type_id: 2 }
      let(:second) { build :measure, geographical_area_id: nil, measure_type_id: 1 }

      it { is_expected.to eq [third, second, first] }
    end
  end

  describe '#supplementary_unit_duty_expression' do
    subject(:supplementary_unit_duty_expression) { create(:measure, :supplementary, :with_measure_components).supplementary_unit_duty_expression }

    it { is_expected.to match(/\.* \(.*\)/) }
  end
end
