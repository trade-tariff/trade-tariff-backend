RSpec.describe GreenLanes::CategoryAssessment do
  before do
    TradeTariffRequest.time_machine_now = Time.current
  end

  describe 'attributes' do
    it { is_expected.to respond_to :id }
    it { is_expected.to respond_to :measure_type_id }
    it { is_expected.to respond_to :regulation_id }
    it { is_expected.to respond_to :theme_id }
    it { is_expected.to respond_to :created_at }
    it { is_expected.to respond_to :updated_at }
    it { is_expected.to respond_to :green_lanes_measure_pks }
    it { is_expected.to respond_to :exemption_pks }
  end

  describe 'validations' do
    subject(:errors) { instance.tap(&:valid?).errors }

    let(:instance) { described_class.new }

    it { is_expected.to include measure_type_id: ['is not present'] }
    it { is_expected.to include regulation_id: ['is not present'] }
    it { is_expected.to include regulation_role: ['is not present'] }
    it { is_expected.to include theme_id: ['is not present'] }

    context 'with duplicate measure_type_id, regulation_id and theme_id' do
      let(:existing) { create :category_assessment }

      let :instance do
        described_class.new measure_type_id: existing.measure_type_id,
                            regulation_id: existing.regulation_id,
                            regulation_role: existing.regulation_role,
                            theme_id: existing.theme_id
      end

      it { is_expected.to include %i[measure_type_id regulation_id regulation_role theme_id] => ['is already taken'] }
    end
  end

  describe 'date fields' do
    subject { create(:category_assessment).reload }

    it { is_expected.to have_attributes created_at: be_within(1.minute).of(Time.zone.now) }
    it { is_expected.to have_attributes updated_at: be_within(1.minute).of(Time.zone.now) }
  end

  describe 'associations' do
    describe '#theme' do
      subject { category_assessment.reload.theme }

      let(:category_assessment) { create :category_assessment, theme: }
      let(:theme) { create :green_lanes_theme }

      it { is_expected.to eq theme }

      context 'with for different theme' do
        let(:second_theme) { create :green_lanes_theme }

        it { is_expected.not_to eq second_theme }
      end
    end

    describe '#measure_type' do
      subject { category_assessment.reload.measure_type }

      let(:category_assessment) { create :category_assessment, measure_type: }
      let(:measure_type) { create :measure_type }

      it { is_expected.to eq measure_type }

      context 'with different measure_type' do
        let(:second_measure_type) { create :measure_type }

        it { is_expected.not_to eq second_measure_type }
      end
    end

    describe '#base_regulation' do
      subject { category_assessment.reload.base_regulation }

      let(:category_assessment) { create :category_assessment, base_regulation: }
      let(:base_regulation) { create :base_regulation }

      it { is_expected.to eq base_regulation }

      context 'with different base_regulation' do
        let(:second_regulation) { create :base_regulation }

        it { is_expected.not_to eq second_regulation }
      end
    end

    describe '#modification_regulation' do
      subject { category_assessment.reload.modification_regulation }

      let(:category_assessment) { create :category_assessment, modification_regulation: }
      let(:modification_regulation) { create :modification_regulation }

      it { is_expected.to eq modification_regulation }

      context 'with different modification_regulation' do
        let(:second_regulation) { create :modification_regulation }

        it { is_expected.not_to eq second_regulation }
      end
    end

    describe '#measures' do
      subject(:measures) { ca.reload.measures }

      let(:ca) { create :category_assessment, :with_measures }

      context :first_measure do
        subject { measures.first }

        it { is_expected.to have_attributes measure_type_id: ca.measure_type_id }
        it { is_expected.to have_attributes measure_generating_regulation_id: ca.regulation_id }
        it { is_expected.to have_attributes measure_generating_regulation_role: ca.regulation_role }
      end

      context :random_measure do
        subject { measures.map(&:measure_type_id) }

        let :second_measure do
          create :measure,
                 measure_type_id: MeasureType.first.measure_type_id.to_i + 10,
                 measure_generating_regulation_id: BaseRegulation.first.base_regulation_id,
                 measure_generating_regulation_role: BaseRegulation.first.base_regulation_role
        end

        it { is_expected.not_to include second_measure.measure_type_id }
      end

      context 'for assessment with expired measures' do
        before do
          ca.measures.first.tap { |m| m.update(validity_end_date: 5.days.ago) }
          ca.reload
        end

        it_with_refresh_materialized_view 'returns empty measures' do
          expect(measures).to be_empty
        end
      end
    end

    describe '#green_lanes_measures' do
      subject { assessment.green_lanes_measures }

      let :assessment do
        create(:category_assessment, :with_green_lanes_measure).tap do |ca|
          create :green_lanes_measure, category_assessment_id: ca.id
        end
      end

      it { is_expected.to include instance_of GreenLanes::Measure }
    end

    describe '#exemptions' do
      subject { assessment.reload.exemptions }

      let :assessment do
        create(:category_assessment).tap do |ca|
          ca.add_exemption create(:green_lanes_exemption)
        end
      end

      it { is_expected.to include instance_of GreenLanes::Exemption }
    end

    describe '#exemption_ids' do
      subject { assessment.reload.exemption_pks }

      let :assessment do
        create(:category_assessment).tap do |ca|
          ca.exemption_pks = exemptions.map(&:pk)
          ca.save
        end
      end

      let(:exemptions) { create_list :green_lanes_exemption, 1 }

      it { is_expected.to match_array exemptions.map(&:id) }
    end
  end

  describe '#regulation' do
    subject { assessment.reload.regulation }

    let :assessment do
      create :category_assessment, regulation_id: regulation&.regulation_id,
                                   regulation_role: regulation&.role
    end

    context 'with modification regulation' do
      let(:regulation) { create :base_regulation }

      it { is_expected.to eq regulation }
    end

    context 'with base regulation' do
      let(:regulation) { create :modification_regulation }

      it { is_expected.to eq regulation }
    end
  end

  describe '#regulation=' do
    subject { assessment }

    before { assessment.regulation = new_regulation }

    let(:persisted) { assessment.tap(&:save).reload }
    let(:regulation) { create :base_regulation }

    let :assessment do
      create :category_assessment, regulation_id: regulation&.regulation_id,
                                   regulation_role: regulation&.role
    end

    context 'with modification regulation' do
      let(:new_regulation) { create :modification_regulation }

      it { is_expected.to have_attributes base_regulation: nil }
      it { is_expected.to have_attributes modification_regulation: new_regulation }

      it 'is updates relationship attributes' do
        expect(assessment).to have_attributes regulation_id: new_regulation.regulation_id,
                                              regulation_role: new_regulation.role
      end

      it 'is is still updated after save and reload' do
        expect(persisted).to have_attributes regulation_id: new_regulation.regulation_id,
                                             regulation_role: new_regulation.role
      end
    end

    context 'with base regulation' do
      let(:regulation) { create :modification_regulation }
      let(:new_regulation) { create :base_regulation }

      it { is_expected.to have_attributes base_regulation: new_regulation }
      it { is_expected.to have_attributes modification_regulation: nil }

      it 'is updates relationship attributes' do
        expect(assessment).to have_attributes regulation_id: new_regulation.regulation_id,
                                              regulation_role: new_regulation.role
      end

      it 'is is still updated after save and reload' do
        expect(persisted).to have_attributes regulation_id: new_regulation.regulation_id,
                                             regulation_role: new_regulation.role
      end
    end
  end

  describe '#combined_measures' do
    subject { category_assessment.combined_measures }

    let(:tariff_measure) { create :measure, :with_base_regulation }
    let(:category_assessment) { create :category_assessment, :with_green_lanes_measure, measure: tariff_measure }

    context 'with tariff measure' do
      it { is_expected.to include tariff_measure }
    end

    context 'with green lanes measure' do
      before { green_lanes_measure }

      let(:green_lanes_measure) { create :green_lanes_measure, category_assessment: }
      let(:category_assessment) { create :category_assessment, :with_green_lanes_measure }

      it { is_expected.to include green_lanes_measure }
    end

    context 'with both types of measure' do
      before { green_lanes_measure }

      let(:green_lanes_measure) { create :green_lanes_measure, category_assessment: }

      it { is_expected.to include tariff_measure }
      it { is_expected.to include green_lanes_measure }
    end

    context 'with expired goods_nomenclature' do
      before { green_lanes_measure.goods_nomenclature.update validity_end_date: 2.days.ago }

      let(:green_lanes_measure) { create :green_lanes_measure, category_assessment: }

      it { is_expected.to include tariff_measure }

      it_with_refresh_materialized_view 'not return gl measures' do
        expect(category_assessment.combined_measures).not_to include green_lanes_measure
      end
    end
  end

  describe '#active_green_lanes_measures' do
    subject { assessment.active_green_lanes_measures }

    let :assessment do
      create(:category_assessment, :with_green_lanes_measure).tap do |ca|
        create :green_lanes_measure, category_assessment_id: ca.id
      end
    end

    let(:gl_measure) { assessment.green_lanes_measures.first }

    it { is_expected.to include gl_measure }

    context 'with expired goods_nomenclature' do
      before do
        gl_measure.goods_nomenclature.update validity_end_date: 2.days.ago
        assessment.reload
      end

      it_with_refresh_materialized_view 'not return gl measures' do
        expect(assessment.active_green_lanes_measures).not_to include gl_measure
      end
    end
  end

  describe '#latest' do
    subject { described_class.latest }

    before { older && newer }

    let(:older) { create :category_assessment, updated_at: 20.minutes.ago }
    let(:newer) { create :category_assessment, updated_at: 2.minutes.ago }

    it { is_expected.to eq_pk newer }
  end
end
