require 'rails_helper'

RSpec.describe GreenLanes::CategoryAssessment do
  describe 'attributes' do
    it { is_expected.to respond_to :id }
    it { is_expected.to respond_to :measure_type_id }
    it { is_expected.to respond_to :regulation_id }
    it { is_expected.to respond_to :theme_id }
    it { is_expected.to respond_to :created_at }
    it { is_expected.to respond_to :updated_at }
  end

  describe 'validations' do
    subject(:errors) { instance.tap(&:valid?).errors }

    let(:instance) { described_class.new }

    it { is_expected.to include measure_type_id: ['is not present'] }
    it { is_expected.to include regulation_id: ['is not present'] }
    it { is_expected.to include regulation_role: ['is not present'] }
    it { is_expected.to include theme_id: ['is not present'] }

    context 'with duplicate measure_type_id and regulation_id' do
      let(:existing) { create :category_assessment }

      let :instance do
        described_class.new measure_type_id: existing.measure_type_id,
                            regulation_id: existing.regulation_id,
                            regulation_role: existing.regulation_role
      end

      it { is_expected.to include %i[measure_type_id regulation_id regulation_role] => ['is already taken'] }
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

      xcontext 'for assessment without regulation' do
        before { measure1 && measure2 }

        let(:ca) { create :category_assessment, :without_regulation }
        let(:measure1) { create :measure, measure_type_id: ca.measure_type_id }
        let(:measure2) { create :measure, measure_type_id: ca.measure_type_id }
        let(:measure3) { create :measure, measure_type_id: ca.measure_type_id.to_i + 1 }

        xit { is_expected.to include measure1 }
        xit { is_expected.to include measure2 }
        it { is_expected.not_to include measure3 }
      end

      context 'for assessment with expired measures' do
        before do
          ca.measures.first.tap { |m| m.update(validity_end_date: 5.days.ago) }
          ca.reload
        end

        it { is_expected.to be_empty }
      end
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
end
