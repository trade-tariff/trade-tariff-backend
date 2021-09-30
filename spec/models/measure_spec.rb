RSpec.describe Measure do
  describe '#id' do
    let(:measure) { build :measure }

    it 'is an alias to #measure_sid' do
      expect(measure.id).to eq measure.measure_sid
    end
  end

  describe '#generating_regulation' do
    let(:measure_of_base_regulation) { create :measure }
    let(:measure_of_modification_regulation) { create :measure, :with_modification_regulation }

    it 'returns relevant regulation that is generating the measure' do
      expect(measure_of_base_regulation.generating_regulation).to eq measure_of_base_regulation.base_regulation
      expect(measure_of_modification_regulation.generating_regulation).to eq measure_of_modification_regulation.modification_regulation
    end
  end

  describe '#measures with different dates' do
    it 'returns all measures that are relevant to the modification regulation' do
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

      expect(described_class.with_modification_regulations.all.count).to eq 3
      # Measures on a parent code should also be present (e.g. 0805201000 on 0805201005)
      expect(Commodity.by_code('0805201005').first.measures.count).to eq 3
      # In TimeMachine we should only see vaild/the correct measure (with start date within the time range)
      # expect(TimeMachine.at(DateTime.parse("2016-07-21")){ Measure.with_modification_regulations.with_actual(ModificationRegulation).all.count }).to eq 1
      expect(TimeMachine.at(DateTime.parse('2016-07-21')) { described_class.with_modification_regulations.with_actual(ModificationRegulation).all.first.measure_sid }).to eq 3_445_396
      expect(TimeMachine.at(DateTime.parse('2016-07-21')) { Commodity.by_code('0805201005').first.measures.count }).to eq 1
      expect(TimeMachine.at(DateTime.parse('2016-07-21')) { Commodity.by_code('0805201005').first.measures.first.measure_sid }).to eq 3_445_396
    end
  end

  # According to Taric guide
  describe '#validity_end_date' do
    let(:base_regulation) { create :base_regulation, effective_end_date: Date.yesterday }
    let(:measure) do
      create :measure, measure_generating_regulation_role: 1,
                       base_regulation: base_regulation,
                       validity_end_date: Date.current
    end

    context 'measure end date greater than generating regulation end date' do
      it 'returns validity end date of' do
        expect(measure.validity_end_date.to_date).to eq base_regulation.effective_end_date.to_date
      end
    end

    context 'measure end date lesser than generating regulation end date' do
      let(:base_regulation) { create :base_regulation, effective_end_date: Date.current }
      let(:measure) do
        create :measure, measure_generating_regulation_role: 1,
                         base_regulation: base_regulation,
                         validity_end_date: Date.yesterday
      end

      it 'returns validity end date of the measure' do
        expect(measure.validity_end_date.to_date).to eq measure.validity_end_date.to_date
      end
    end

    context 'generating regulation effective end date blank, measure end date blank' do
      let(:base_regulation) { create :base_regulation, effective_end_date: nil }
      let(:measure) do
        create :measure, measure_generating_regulation_role: 1,
                         base_regulation: base_regulation,
                         validity_end_date: nil
      end

      it 'returns validity end date of the measure' do
        expect(measure.validity_end_date).to be_blank
      end
    end

    context 'generating regulation effective end date blank, measure end date present' do
      let(:base_regulation) { create :base_regulation, effective_end_date: nil }
      let(:measure) do
        create :measure, measure_generating_regulation_role: 1,
                         base_regulation: base_regulation,
                         validity_end_date: Date.current
      end

      it 'returns validity end date of the measure' do
        expect(measure.validity_end_date).to be_blank
      end
    end

    context 'generating regulation effective end date present, measure end date blank' do
      let(:base_regulation) { create :base_regulation, effective_end_date: Date.current }
      let(:measure) do
        create :measure, measure_generating_regulation_role: 1,
                         base_regulation: base_regulation,
                         validity_end_date: nil
      end

      it 'returns validity end date of the measure' do
        expect(measure.validity_end_date.to_date).to eq Date.current
      end
    end

    context 'measure is national' do
      let(:base_regulation) { create :base_regulation, effective_end_date: Date.yesterday }
      let(:measure) do
        create :measure, measure_generating_regulation_role: 1,
                         base_regulation: base_regulation,
                         validity_end_date: Date.current,
                         national: true
      end

      it 'returns validity end date of the measure' do
        expect(measure.validity_end_date.to_date).to eq Date.current
      end
    end
  end

  describe 'associations' do
    describe 'measure type' do
      let!(:measure)         { create :measure }
      let!(:measure_type1)   do
        create :measure_type, measure_type_id: measure.measure_type_id,
                              validity_start_date: 5.years.ago,
                              validity_end_date: 3.years.ago,
                              operation_date: Date.yesterday
      end
      let!(:measure_type2) do
        create :measure_type, measure_type_id: measure.measure_type_id,
                              validity_start_date: 2.years.ago,
                              validity_end_date: nil,
                              operation: :update
      end

      context 'direct loading' do
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

      context 'eager loading' do
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

      context 'direct loading' do
        it 'loads associated measure conditions' do
          expect(measure.measure_conditions).to include measure_condition1
        end

        it 'does not load associated measure condition' do
          expect(measure.measure_conditions).not_to include measure_condition2
        end
      end

      context 'eager loading' do
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
          expect(measure.measure_conditions.first).to eq measure_condition2
          expect(measure.measure_conditions.last).to eq measure_condition1
        end
      end
    end

    describe 'geographical area' do
      let!(:geographical_area1)     { create :geographical_area, geographical_area_id: 'ab' }
      let!(:geographical_area2)     { create :geographical_area, geographical_area_id: 'de' }
      let!(:measure)                { create :measure, geographical_area_sid: geographical_area1.geographical_area_sid }

      context 'direct loading' do
        it 'loads associated measure conditions' do
          expect(measure.geographical_area.pk).to eq geographical_area1.pk
        end

        it 'does not load associated measure condition' do
          expect(measure.geographical_area.pk).not_to eq geographical_area2.pk
        end
      end

      context 'eager loading' do
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
      let!(:footnote1_assoc) do
        create :footnote_association_measure, measure_sid: measure.measure_sid,
                                              footnote_id: footnote1.footnote_id,
                                              footnote_type_id: footnote1.footnote_type_id
      end
      let!(:footnote2) do
        create :footnote, validity_start_date: 5.years.ago,
                          validity_end_date: 3.years.ago
      end
      let!(:footnote2_assoc) do
        create :footnote_association_measure, measure_sid: measure.measure_sid,
                                              footnote_id: footnote2.footnote_id,
                                              footnote_type_id: footnote2.footnote_type_id
      end

      context 'direct loading' do
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

      context 'order' do
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

      context 'eager loading' do
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
      let!(:measure_component3)     { create :measure_component, measure_sid: measure.measure_sid, duty_expression_id: '01' }

      context 'direct loading' do
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

      context 'eager loading' do
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
      let!(:additional_code1)     { create :additional_code, validity_start_date: Date.current.ago(3.years) }
      let!(:additional_code2)     { create :additional_code, validity_start_date: Date.current.ago(5.years) }
      let!(:measure)              { create :measure, additional_code_sid: additional_code1.additional_code_sid }

      context 'direct loading' do
        it 'loads associated measure conditions' do
          expect(measure.additional_code).to eq additional_code1
        end

        it 'does not load associated measure condition' do
          expect(measure.additional_code).not_to eq additional_code2
        end
      end

      context 'eager loading' do
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
      let!(:quota_order_number1)     { create :quota_order_number, validity_start_date: Date.current.ago(3.years) }
      let!(:quota_order_number2)     { create :quota_order_number, validity_start_date: Date.current.ago(5.years) }
      let!(:measure)                 { create :measure, ordernumber: quota_order_number1.quota_order_number_id }

      context 'direct loading' do
        it 'loads associated measure conditions' do
          expect(measure.quota_order_number).to eq quota_order_number1
        end

        it 'does not load associated measure condition' do
          expect(measure.quota_order_number).not_to eq quota_order_number2
        end
      end

      context 'eager loading' do
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
      let!(:fts_regulation1)        { create :fts_regulation, validity_start_date: Date.current.ago(3.years) }
      let!(:fts_regulation2)        { create :fts_regulation, validity_start_date: Date.current.ago(5.years) }
      let!(:fts_regulation_action1) { create :fts_regulation_action, fts_regulation_id: fts_regulation1.full_temporary_stop_regulation_id }
      let!(:fts_regulation_action2) { create :fts_regulation_action, fts_regulation_id: fts_regulation2.full_temporary_stop_regulation_id }
      let!(:measure)                { create :measure, measure_generating_regulation_id: fts_regulation_action1.stopped_regulation_id }

      context 'direct loading' do
        it 'loads associated full temporary stop regulation' do
          expect(measure.full_temporary_stop_regulation.pk).to eq fts_regulation1.pk
        end

        it 'does not load associated full temporary stop regulation' do
          expect(measure.full_temporary_stop_regulation.pk).not_to eq fts_regulation2.pk
        end
      end

      context 'eager loading' do
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
      let!(:mpt_stop1)        { create :measure_partial_temporary_stop, validity_start_date: Date.current.ago(3.years) }
      let!(:mpt_stop2)        { create :measure_partial_temporary_stop, validity_start_date: Date.current.ago(5.years) }
      let!(:measure)          { create :measure, measure_generating_regulation_id: mpt_stop1.partial_temporary_stop_regulation_id, measure_sid: mpt_stop1.measure_sid }

      context 'direct loading' do
        it 'loads associated full temporary stop regulation' do
          expect(measure.measure_partial_temporary_stop.pk).to eq mpt_stop1.pk
        end

        it 'does not load associated full temporary stop regulation' do
          expect(measure.measure_partial_temporary_stop.pk).not_to eq mpt_stop2.pk
        end
      end

      context 'eager loading' do
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
    before(:all) { described_class.unrestrict_primary_key }

    it 'is uk' do
      expect(described_class.new(measure_sid: -1).origin).to eq 'uk'
    end

    it 'is eu' do
      expect(described_class.new(measure_sid: 1).origin).to eq 'eu'
    end
  end

  describe '#measure_generating_regulation_id' do
    it 'reads measure generating regulation id from database' do
      measure = create :measure
      expect(measure.measure_generating_regulation_id).not_to be_blank
      expect(measure.measure_generating_regulation_id).to eq described_class.first.measure_generating_regulation_id
    end

    it 'measure D9500019 is globally replaced with D9601421' do
      measure = create :measure, measure_generating_regulation_id: 'D9500019'
      expect(measure.measure_generating_regulation_id).not_to be_blank
      expect(measure.measure_generating_regulation_id).to eq 'D9601421'
    end
  end

  describe '#order_number' do
    context 'quota_order_number associated' do
      let(:quota_order_number) { create :quota_order_number }
      let(:measure) { create :measure, ordernumber: quota_order_number.quota_order_number_id }

      it 'returns associated quota order nmber' do
        expect(measure.order_number).to eq quota_order_number
      end
    end

    context 'quota_order_number missing' do
      let(:ordernumber) { 6.times.map { Random.rand(9) }.join }
      let(:measure) { create :measure, ordernumber: ordernumber }

      it 'returns a mock quota order number with just the number set' do
        expect(measure.order_number.quota_order_number_id).to eq ordernumber
      end

      it 'associated mock quota order number should have no quota definition' do
        expect(measure.order_number.quota_definition).to be_blank
      end
    end
  end

  describe '#import' do
    let(:measure) { create :measure, measure_type: measure_type }

    context 'measure type is import' do
      let(:measure_type) { create :measure_type, :import }

      it 'returns true' do
        expect(measure.import).to be_truthy
      end
    end

    context 'measure type is export' do
      let(:measure_type) { create :measure_type, :export }

      it 'returns false' do
        expect(measure.import).to be_falsy
      end
    end
  end

  describe '#export' do
    let(:measure) { create :measure, measure_type: measure_type }

    context 'measure type is import' do
      let(:measure_type) { create :measure_type, :import }

      it 'returns false' do
        expect(measure.export).to be_falsy
      end
    end

    context 'measure type is export' do
      let(:measure_type) { create :measure_type, :export }

      it 'returns true' do
        expect(measure.export).to be_truthy
      end
    end
  end

  describe '#meursing?' do
    let(:measure) { create :measure }

    context 'any measure components are meursing' do
      let!(:measure_component) do
        create :measure_component,
               measure_sid: measure.measure_sid,
               duty_expression_id: DutyExpression::MEURSING_DUTY_EXPRESSION_IDS.sample
      end

      it 'returns true' do
        expect(measure).to be_meursing
      end
    end

    context 'no measure components are meursing' do
      let!(:measure_component) do
        create :measure_component,
               measure_sid: measure.measure_sid,
               duty_expression_id: 'aaa'
      end

      it 'returns false' do
        expect(measure).not_to be_meursing
      end
    end
  end

  describe '.changes_for' do
    context 'measure validity start date lower than requested date' do
      it 'incudes measure' do
        create :measure, validity_start_date: Date.new(2014, 2, 1)
        TimeMachine.at(Date.new(2014, 1, 30)) do
          expect(described_class.changes_for).to be_empty
        end
      end
    end

    context 'measure validity start date higher than requested date' do
      it 'does not include measure' do
        measure = create :measure, validity_start_date: Date.new(2014, 2, 1)
        TimeMachine.at(Date.new(2014, 2, 1)) do
          expect(described_class.changes_for).not_to be_empty
          expect(described_class.changes_for.first.oid).to eq measure.source.oid
        end
      end

      it 'returns records with NULL operation_date last' do
        create :measure, validity_start_date: Date.new(2014, 2, 1), operation_date: Date.new(2014, 2, 1)
        create :measure, validity_start_date: Date.new(2014, 2, 1)
        TimeMachine.at(Date.new(2014, 2, 1)) do
          changes_for = described_class.changes_for
          expect(changes_for.count).to eq(2)
          expect(changes_for.first.operation_date).to be_truthy
          expect(changes_for.last.operation_date).to be_falsey
        end
      end
    end
  end

  describe '#duty_expression_with_national_measurement_units_for ^ #formatted_duty_expression_with_national_measurement_units_for' do
    let(:commodity) do
      create :commodity
    end
    let(:base) do
      measure.duty_expression_with_national_measurement_units_for(commodity)
    end
    let(:formatted_base) do
      measure.formatted_duty_expression_with_national_measurement_units_for(commodity)
    end
    let(:measure_type) do
      create :measure_type, :excise
    end
    let(:measure) do
      create :measure, measure_type_id: measure_type.measure_type_id
    end
    let(:duty_expression) do
      create(:duty_expression, :with_description)
    end
    let!(:measure_component) do
      create :measure_component, measure_sid: measure.measure_sid,
                                 duty_expression_id: duty_expression.duty_expression_id
    end

    describe '#duty_expression' do
      context 'measure components order' do
        let(:duty_expression2) do
          create(:duty_expression, :with_description, duty_expression_id: '00')
        end
        let!(:measure_component2) do
          create :measure_component, measure_sid: measure.measure_sid,
                                     duty_expression_id: duty_expression2.duty_expression_id
        end

        it 'orders components by duty_expression_id' do
          expect(measure.duty_expression).to eq([measure_component2, measure_component].map(&:duty_expression_str).join(' '))
        end
      end
    end

    describe '#formatted_duty_expression' do
      context 'measure components order' do
        let(:duty_expression2) do
          create(:duty_expression, :with_description, duty_expression_id: '00')
        end
        let!(:measure_component2) do
          create :measure_component, measure_sid: measure.measure_sid,
                                     duty_expression_id: duty_expression2.duty_expression_id
        end

        it 'orders components by duty_expression_id' do
          expect(measure.formatted_duty_expression).to eq([measure_component2, measure_component].map(&:formatted_duty_expression).join(' '))
        end
      end
    end

    context 'without national_measurement_unit' do
      it {
        expect(base).to match Regexp.new(measure_component.duty_expression_str)
      }

      it {
        expect(formatted_base).to match Regexp.new(measure_component.formatted_duty_expression)
      }
    end
  end

  describe '#relevant_for_country?' do
    context 'when the measure excludes the country id' do
      subject(:measure) { exclusion.measure }

      let(:exclusion) { create(:measure_excluded_geographical_area) }

      it 'returns false' do
        expect(measure.relevant_for_country?(exclusion.geographical_area.geographical_area_id)).to eq(false)
      end
    end

    context 'when the measure is a national measure and its geographical area is the world' do
      subject(:measure) { create(:measure, :national, geographical_area_id: '1011') }

      it 'returns true' do
        expect(measure.relevant_for_country?('foo')).to eq(true)
      end
    end

    context 'when the measure has no geographical area' do
      subject(:measure) { create(:measure, geographical_area_sid: nil, geographical_area_id: nil) }

      it 'returns true' do
        expect(measure.relevant_for_country?('foo')).to eq(true)
      end
    end

    context 'when the measure has a geographical area that is the country' do
      subject(:measure) { create(:measure) }

      it 'returns true' do
        expect(measure.relevant_for_country?(measure.geographical_area_id)).to eq(true)
      end
    end

    context 'when the measure has a contained geographical area that is the country' do
      subject(:measure) { create(:measure, geographical_area_sid: geographical_area.geographical_area_sid) }

      let(:geographical_area) { create(:geographical_area, :group) }
      let(:contained_geographical_area) { create(:geographical_area, :country) }

      let!(:membership) { create(:geographical_area_membership, geographical_area_sid: contained_geographical_area.geographical_area_sid, geographical_area_group_sid: geographical_area.geographical_area_sid) }

      it 'returns true' do
        expect(measure.relevant_for_country?(contained_geographical_area.geographical_area_id)).to eq(true)
      end
    end
  end

  describe '#expresses_unit?' do
    context 'when the measure type is one that expresses the unit' do
      context 'when the measure is an ad_valorem measure' do
        subject(:measure) { create(:measure, :with_measure_components, :ad_valorem, :expresses_units) }

        it 'returns false' do
          expect(measure).not_to be_expresses_unit
        end
      end

      context 'when the measure is not ad_valorem measure' do
        subject(:measure) { create(:measure, :with_measure_components, :no_ad_valorem, :expresses_units) }

        it 'returns true' do
          expect(measure).to be_expresses_unit
        end
      end
    end

    context 'when the measure type is one that does not express units' do
      subject(:measure) { create(:measure, :with_measure_components, :no_expresses_units) }

      it 'returns false' do
        expect(measure).not_to be_expresses_unit
      end
    end
  end

  describe '#ad_valorem?' do
    context 'when there are ad valorem conditions' do
      subject(:measure) { create(:measure, :with_measure_conditions, :ad_valorem) }

      it 'returns true' do
        expect(measure).to be_ad_valorem
      end
    end

    context 'when there are ad valorem components' do
      subject(:measure) { create(:measure, :with_measure_components, :ad_valorem) }

      it 'returns true' do
        expect(measure).to be_ad_valorem
      end
    end

    context 'when there are no ad valorem conditions or components' do
      subject(:measure) { create(:measure, :with_measure_components, :with_measure_conditions, :no_ad_valorem) }

      it 'returns false' do
        expect(measure).not_to be_ad_valorem
      end
    end
  end

  describe '#zero_mfn?' do
    context 'when the measure type is a third country' do
      subject(:measure) do
        create(
          :measure,
          :third_country,
          :with_measure_components,
          duty_amount: duty_amount,
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
              duty_amount: duty_amount,
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

#   describe '#meursing_measures_for' do
#     context 'when there are matching meursing measures' do
#       let(:measure) do
#         create(
#           :meursing_measure,
#           additional_code_id: additional_code_id,
#         )
#       end

#       let(:additional_code_id) { '000' }

#       it { expect(measure.meursing_measures_for(additional_code_id).count).to eq(1) }
#     end

#     context 'when there are no matching meursing measures' do
#       let(:measure) { create(:measure) }

#       let(:additional_code_id) { '000' }

#       it { expect(measure.meursing_measures_for(additional_code_id).count).to be_zero }
#     end
#   end
end
