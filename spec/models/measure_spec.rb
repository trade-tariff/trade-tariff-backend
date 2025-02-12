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

      it_behaves_like 'excludes measure type', 'DEFAULT_EXCLUDED_TYPES'
      it_behaves_like 'includes measure type', 'QUOTA_TYPES'
      it_behaves_like 'includes measure type', 'NATIONAL_PR_TYPES'
    end

    context 'for XI service' do
      let(:service) { 'xi' }

      it_behaves_like 'excludes measure type', 'DEFAULT_EXCLUDED_TYPES'
      it_behaves_like 'excludes measure type', 'QUOTA_TYPES'
      it_behaves_like 'excludes measure type', 'NATIONAL_PR_TYPES'
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
      it_behaves_like 'excludes measure type', 'VAT_TYPES', 'FR'
    end

    context 'for UK service with Geographical Area Subject to VAT or Excise' do
      let(:service) { 'uk' }
      let(:geographical_area_id) { GeographicalArea::AREAS_SUBJECT_TO_VAT_OR_EXCISE_ID }

      it_behaves_like 'includes measure type', 'VAT_TYPES'
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

  describe '.excluding_licensed_quotas' do
    subject(:dataset) { described_class.excluding_licensed_quotas }

    before do
      create(:measure, ordernumber: '094001') # licensed and excluded
      create(:measure, ordernumber: '096001') # non-licensed not excluded
    end

    it { expect(dataset.pluck(:ordernumber)).to eq %w[096001] }
  end

  describe '.with_regulation_dates_non_current' do
    subject { described_class.with_regulation_dates_query_non_current.all.first }

    around { |example| TimeMachine.now { example.run } }

    before do
      create(:measure, :with_base_regulation, validity_start_date: 3.days.ago.beginning_of_day, validity_end_date: 2.days.ago.end_of_day)
    end

    it { is_expected.to have_attributes effective_start_date: 3.days.ago.beginning_of_day }
    it { is_expected.to have_attributes effective_end_date: 2.days.ago.end_of_day.floor(6) }
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

  describe '.with_seasonal_measures' do
    subject(:measures) { described_class.with_seasonal_measures(%w[142], %w[AU]).all }

    before do
      start_date = Time.zone.today.beginning_of_year
      end_date = Time.zone.today.end_of_year + 1.year

      create(
        :measure,
        validity_start_date: start_date,
        validity_end_date: start_date + 2.days,
        measure_type_id: '142',
        geographical_area_id: 'AU',
      )

      create( # Excluded start date precedes season range
        :measure,
        validity_start_date: start_date - 1.day,
        validity_end_date: start_date + 2.days,
        measure_type_id: '142',
        geographical_area_id: 'AU',
      )

      create( # Excluded missing validity end date
        :measure,
        validity_start_date: start_date,
        validity_end_date: nil,
        measure_type_id: '142',
        geographical_area_id: 'AU',
      )

      create( # Excluded end date exceeds season range
        :measure,
        validity_start_date: start_date,
        validity_end_date: end_date + 1.day,
        measure_type_id: '142',
        geographical_area_id: 'AU',
      )

      create( # Excluded wrong measure_type
        :measure,
        validity_start_date: start_date,
        validity_end_date: start_date + 2.days,
        measure_type_id: '143',
        geographical_area_id: 'AU',
      )

      create( # Excluded wrong geographical_area_id
        :measure,
        validity_start_date: start_date,
        validity_end_date: start_date + 2.days,
        measure_type_id: '143',
        geographical_area_id: 'AU',
      )
    end

    it { is_expected.to have_attributes length: 1 }
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

      it { expect(measure.base_regulation).to be_present }
    end

    context 'when base regulation approved_flag is set to false' do
      let(:measure) { create :measure, :with_unapproved_base_regulation }

      it { expect(measure.base_regulation).to be_nil }
    end
  end

  describe '#modification_regulation' do
    context 'when modification regulation approved_flag is set to true' do
      let(:measure) { create :measure, :with_modification_regulation }

      it { expect(measure.modification_regulation).to be_present }
    end

    context 'when modification regulation approved_flag is set to false' do
      let(:measure) { create :measure, :with_unapproved_modification_regulation }

      it { expect(measure.modification_regulation).to be_nil }
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

      it { expect(measure.import).to be(true) }
    end

    context 'when the measure type is export' do
      let(:measure_type) { create :measure_type, :export }

      it { expect(measure.import).to be(false) }
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
    subject { measure.relevant_for_country? country.geographical_area_id }

    context 'when the measure excludes the country id' do
      let(:measure) { create(:measure, :with_measure_excluded_geographical_area) }
      let(:country) { measure.geographical_area.contained_geographical_areas.first }

      it { is_expected.to be false }
    end

    context 'when the measure excludes a group the country belongs to' do
      let(:measure) { create(:measure, :with_measure_excluded_geographical_area_group) }

      let(:country) do
        measure
          .measure_excluded_geographical_areas
          .first
          .geographical_area
          .contained_geographical_areas
          .first
      end

      it { is_expected.to be false }
    end

    context 'when the measure excludes a referenced group the country belongs to' do
      let(:measure) { create(:measure, :with_measure_excluded_geographical_area_referenced_group) }

      let(:country) do
        measure
          .measure_excluded_geographical_areas
          .first
          .geographical_area
          .referenced
          .contained_geographical_areas
          .first
      end

      it { is_expected.to be false }
    end

    context 'when the measure is a national measure and its geographical area is the world' do
      let(:measure) { create(:measure, :national, geographical_area_id: '1011') }
      let(:country) { build(:geographical_area) }

      it { is_expected.to be true }
    end

    context 'when the measure has a meursing measure type and its geographical area is the world' do
      let(:measure) { create(:measure, :flour, geographical_area_id: '1011') }
      let(:country) { build(:geographical_area) }

      it { is_expected.to be true }
    end

    context 'when the measure has no geographical area' do
      let(:measure) { create(:measure, geographical_area_sid: nil, geographical_area_id: nil) }
      let(:country) { build(:geographical_area) }

      it { is_expected.to be true }
    end

    context 'when the measure has a geographical area that is the country' do
      let(:measure) { create(:measure) }
      let(:country) { measure.geographical_area }

      it { is_expected.to be true }
    end

    context 'when the measure has a contained geographical area that is the country' do
      subject { measure.relevant_for_country? contained_geographical_area.geographical_area_id }

      let(:measure) { create(:measure, geographical_area_sid: geographical_area.geographical_area_sid) }
      let(:geographical_area) { create(:geographical_area, :group) }
      let(:contained_geographical_area) { create(:geographical_area, :country) }

      before do
        create(
          :geographical_area_membership,
          geographical_area_sid: contained_geographical_area.geographical_area_sid,
          geographical_area_group_sid: geographical_area.geographical_area_sid,
        )
      end

      it { is_expected.to be true }
    end

    context 'when the measure has a referenced contained geographical area that is the country' do
      subject { measure.relevant_for_country? 'FR' }

      let(:measure) { create(:measure, geographical_area_sid: geographical_area.geographical_area_sid, geographical_area_id: 'EU') }
      let(:geographical_area) { create(:geographical_area, :with_reference_group_and_members, geographical_area_id: 'EU') }

      it { is_expected.to be true }
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
          allow(MeursingMeasureFinderService).to receive(:new).and_return(instance_double(MeursingMeasureFinderService, call: []))
          allow(MeursingMeasureComponentResolverService).to receive(:new).and_return(instance_double(MeursingMeasureComponentResolverService, call: [measure_unit_component]))
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
        allow(MeursingMeasureFinderService).to receive(:new).and_return(instance_double(MeursingMeasureFinderService, call: []))
        allow(MeursingMeasureComponentResolverService).to receive(:new).and_return(
          instance_double(
            MeursingMeasureComponentResolverService,
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
    shared_context 'when on the coercian start date' do
      around do |example|
        TimeMachine.at(Date.new(2023, 8, 1)) do
          example.run
        end
      end
    end

    shared_context 'when before the coercian start date' do
      around do |example|
        TimeMachine.at(Date.new(2023, 7, 28)) do
          example.run
        end
      end
    end

    let(:expected_units) do
      [
        {
          measurement_unit_code: 'DTN',
          measurement_unit_qualifier_code: 'R',
        },
      ]
    end

    context 'when there are measure conditions and measure components' do
      subject(:measure) { create(:measure, :with_measure_components, :with_measure_conditions) }

      it { expect(measure.units).to eq(expected_units) }
    end

    context 'when there are only measure components' do
      subject(:measure) { create(:measure, :with_measure_components) }

      it { expect(measure.units).to eq(expected_units) }
    end

    context 'when there are only measure conditions' do
      subject(:measure) do
        create(
          :measure,
          :with_measure_conditions,
          :excise,
          condition_measurement_unit_code: 'ASV',
          condition_measurement_unit_qualifier_code: 'X',
          measurement_unit_code: 'DTN',
          measurement_unit_qualifier_code: 'R',
        )
      end

      include_context 'when before the coercian start date' do
        it { expect(measure.units).to eq(expected_units) }
      end

      include_context 'when on the coercian start date' do
        before do
          expected_units << {
            measurement_unit_code: 'ASV',
            measurement_unit_qualifier_code: 'X',
          }
        end

        it { expect(measure.units).to eq(expected_units) }
      end
    end

    context 'when there are no measure conditions or components' do
      subject(:measure) { create(:measure) }

      it { expect(measure.units).to eq([]) }
    end
  end

  describe '#resolved_measure_components' do
    subject(:measure) { create(:measure) }

    before do
      allow(MeursingMeasureFinderService).to receive(:new).and_return(instance_double(MeursingMeasureFinderService, call: meursing_measures))
      allow(MeursingMeasureComponentResolverService).to receive(:new).and_return(instance_double(MeursingMeasureComponentResolverService, call: resolved_components))
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
      allow(MeursingMeasureFinderService).to receive(:new).and_return(instance_double(MeursingMeasureFinderService, call: meursing_measures))
      allow(MeursingMeasureComponentResolverService).to receive(:new).and_return(instance_double(MeursingMeasureComponentResolverService, call: resolved_components))
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
        MeursingMeasureFinderService,
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

  describe '.with_additional_code_sid' do
    subject(:dataset) { described_class.with_additional_code_sid(additional_code_sid) }

    before do
      create(:measure, additional_code_sid: 1)
      create(:measure, additional_code_sid: 2)
    end

    context 'when additional_code_sid is nil' do
      let(:additional_code_sid) { nil }

      it 'applies no filter' do
        expect(dataset.pluck(:additional_code_sid)).to eq [1, 2]
      end
    end

    context 'when additional_code_sid is present' do
      let(:additional_code_sid) { 1 }

      it 'applies the filter' do
        expect(dataset.pluck(:additional_code_sid)).to eq [1]
      end
    end
  end

  describe '.with_additional_code_type' do
    subject(:dataset) { described_class.with_additional_code_type(additional_code_type_id) }

    before do
      create(:measure, additional_code_type_id: 'A')
      create(:measure, additional_code_type_id: 'B')
    end

    context 'when additional_code_type_id is nil' do
      let(:additional_code_type_id) { nil }

      it 'applies no filter' do
        expect(dataset.pluck(:additional_code_type_id)).to eq %w[A B]
      end
    end

    context 'when additional_code_type_id is present' do
      let(:additional_code_type_id) { 'A' }

      it 'applies the filter' do
        expect(dataset.pluck(:additional_code_type_id)).to eq %w[A]
      end
    end
  end

  describe '.with_additional_code_id' do
    subject(:dataset) { described_class.with_additional_code_id(additional_code_id) }

    before do
      create(:measure, additional_code_id: '700')
      create(:measure, additional_code_id: '800')
    end

    context 'when additional_code_id is nil' do
      let(:additional_code_id) { nil }

      it 'applies no filter' do
        expect(dataset.pluck(:additional_code_id)).to eq %w[700 800]
      end
    end

    context 'when additional_code_id is present' do
      let(:additional_code_id) { '700' }

      it 'applies the filter' do
        expect(dataset.pluck(:additional_code_id)).to eq %w[700]
      end
    end
  end

  describe '.join_measure_conditions' do
    subject(:measures) { described_class.join_measure_conditions.all }

    before do
      # create a measure condition without a measure - this should not be returned
      create(:measure_condition, measure_sid: 99_999_999)
      # create a measure condition with a measure
      create(:measure_condition, measure:)
      # create a measure condition with the same measure as the previous one
      create(:measure_condition, measure:)
    end

    let(:measure) { create(:measure) }

    it 'returns a measure for each condition' do
      expect(measures.count).to eq 2
    end

    it 'returns measures that are the same' do
      expect(measures.first).to eq_pk measures.second
    end

    it 'returns measures with measure condition attributes attached' do
      expect(measures.pluck(:condition_duty_amount)).to all(be_present)
    end
  end

  describe '.with_certificate_type_code' do
    subject(:dataset) { described_class.join_measure_conditions.with_certificate_type_code(certificate_type_code) }

    let(:measure) { create(:measure) }

    before do
      create(
        :measure_condition,
        measure: create(:measure),
        certificate_type_code: 'Y',
      )
      create(
        :measure_condition,
        measure: create(:measure),
        certificate_type_code: 'N',
      )
    end

    context 'when certificate_type_code is nil' do
      let(:certificate_type_code) { nil }

      it 'applies no filter' do
        expect(dataset.pluck(:certificate_type_code)).to eq %w[Y N]
      end
    end

    context 'when certificate_type_code is present' do
      let(:certificate_type_code) { 'Y' }

      it 'applies the filter' do
        expect(dataset.pluck(:certificate_type_code)).to eq %w[Y]
      end
    end
  end

  describe '.with_certificate_code' do
    subject(:dataset) { described_class.join_measure_conditions.with_certificate_code(certificate_code) }

    let(:measure) { create(:measure) }

    before do
      create(
        :measure_condition,
        measure: create(:measure),
        certificate_code: '123',
      )
      create(
        :measure_condition,
        measure: create(:measure),
        certificate_code: '456',
      )
    end

    context 'when certificate_code is nil' do
      let(:certificate_code) { nil }

      it 'applies no filter' do
        expect(dataset.pluck(:certificate_code)).to eq %w[123 456]
      end
    end

    context 'when certificate_code is present' do
      let(:certificate_code) { '123' }

      it 'applies the filter' do
        expect(dataset.pluck(:certificate_code)).to eq %w[123]
      end
    end
  end

  describe '.with_certificate_types_and_codes' do
    subject(:dataset) { described_class.join_measure_conditions.with_certificate_types_and_codes(certificate_types_and_codes) }

    before do
      measure = create(:measure)
      create(
        :measure_condition,
        measure:,
        certificate_type_code: 'Y',
        certificate_code: '123',
      )
      create(
        :measure_condition,
        measure:,
        certificate_type_code: 'N',
        certificate_code: '456',
      )
      create(
        :measure_condition,
        measure:,
        certificate_type_code: 'Z',
        certificate_code: '789',
      )
    end

    context 'when certificate_types_and_codes is empty' do
      let(:certificate_types_and_codes) { [] }

      it 'applies no filter' do
        expect(dataset.pluck(:certificate_code)).to eq %w[123 456 789]
      end
    end

    context 'when certificate_types_and_codes is present' do
      let(:certificate_types_and_codes) do
        [
          %w[Y 123],
          %w[N 456],
        ]
      end

      it 'applies the filter' do
        expect(dataset.pluck(:certificate_code)).to eq %w[123 456]
      end
    end
  end

  describe '.with_footnote_type_id' do
    subject(:dataset) { described_class.join_footnotes.with_footnote_type_id('01') }

    before do
      measure = create(:measure)

      create(:footnote, :with_measure_association, measure:, footnote_type_id: '01')
      create(:footnote, :with_measure_association, measure:, footnote_type_id: '02')
    end

    it { is_expected.to all(be_a(described_class)) }
    it { expect(dataset.pluck(:footnote_type_id)).to eq(%w[01]) }
  end

  describe '.with_footnote_id' do
    subject(:dataset) { described_class.join_footnotes.with_footnote_id('123') }

    before do
      measure = create(:measure)

      create(:footnote, :with_measure_association, measure:, footnote_id: '123')
      create(:footnote, :with_measure_association, measure:, footnote_id: '456')
    end

    it { is_expected.to all(be_a(described_class)) }
    it { expect(dataset.pluck(:footnote_id)).to eq(%w[123]) }
  end

  describe '.with_footnote_types_and_ids' do
    subject(:dataset) { described_class.join_footnotes.with_footnote_types_and_ids(footnote_types_and_ids) }

    before do
      measure = create(:measure)

      create(
        :footnote,
        :with_measure_association,
        measure:,
        footnote_type_id: 'Y',
        footnote_id: '123',
      )
      create(
        :footnote,
        :with_measure_association,
        measure:,
        footnote_type_id: 'N',
        footnote_id: '456',
      )
      create(
        :footnote,
        :with_measure_association,
        measure:,
        footnote_type_id: 'Z',
        footnote_id: '789',
      )
    end

    context 'when footnote_types_and_ids is empty' do
      let(:footnote_types_and_ids) { [] }

      it { expect(dataset.pluck(:footnote_id)).to eq %w[123 456 789] }
      it { expect(dataset.pluck(:footnote_type_id)).to eq %w[Y N Z] }
    end

    context 'when footnote_types_and_ids is present' do
      let(:footnote_types_and_ids) do
        [
          %w[Y 123],
          %w[N 456],
        ]
      end

      it { expect(dataset.pluck(:footnote_id)).to eq %w[123 456] }
      it { expect(dataset.pluck(:footnote_type_id)).to eq %w[Y N] }
    end
  end

  describe '.national' do
    let(:national_measure) { create(:measure, :national) }
    let(:non_national_measure) { create(:measure) }

    before do
      national_measure
      non_national_measure
    end

    it { expect(described_class.national.all).to eq([national_measure]) }
  end

  describe '#category_assessment' do
    subject { measure.reload.category_assessment }

    let(:measure) { create :measure, :with_base_regulation, :with_measure_type }

    context 'with matching category_assessment' do
      before { category_assessment }

      let :category_assessment do
        create :category_assessment, measure_type: measure.measure_type,
                                     regulation: measure.generating_regulation
      end

      it { is_expected.to eq_pk category_assessment }
    end

    context 'without matching category_assessment' do
      let(:measure) { create :measure }

      it { is_expected.to be_nil }
    end
  end
end
