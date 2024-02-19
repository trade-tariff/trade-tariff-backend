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
    it { is_expected.not_to include :regulation_id }
    it { is_expected.not_to include :regulation_role }
    it { is_expected.to include theme_id: ['is not present'] }

    context 'with regulation_id but not regulation_role' do
      let(:instance) { described_class.new regulation_id: 1 }

      it { is_expected.to include regulation_role: ['is not present'] }
    end

    context 'without regulation_id but with regulation_role' do
      let(:instance) { described_class.new regulation_role: 1 }

      it { is_expected.to include regulation_id: ['is not present'] }
    end

    context 'with duplicate measure_type_id and regulation_id' do
      let(:existing) { create :category_assessment }

      let :instance do
        described_class.new measure_type_id: existing.measure_type_id,
                            regulation_id: existing.regulation_id,
                            regulation_role: existing.regulation_role
      end

      it { is_expected.to include %i[measure_type_id regulation_id regulation_role] => ['is already taken'] }
    end

    context 'with new category assessment for specific regulation and with existing category assessment for all regulations' do
      let(:existing) { create :category_assessment, regulation_id: nil, regulation_role: nil }
      let(:instance) { build :category_assessment, measure_type_id: existing.measure_type_id }

      it { is_expected.to include %i[measure_type_id regulation_id regulation_role] => ['is already taken'] }
    end

    context 'with new category assessment for all regulations and existing assessment for specific regulations' do
      let(:existing) { create :category_assessment }

      let :instance do
        build :category_assessment, measure_type_id: existing.measure_type_id,
                                    regulation_id: nil,
                                    regulation_role: nil
      end

      it { is_expected.to include %i[measure_type_id regulation_id regulation_role] => ['is already taken'] }
    end

    context 'with new category assessment for all regulations and existing assessment for all regulations' do
      let(:existing) { create :category_assessment, regulation_id: nil, regulation_role: nil }

      let :instance do
        build :category_assessment, measure_type_id: existing.measure_type_id,
                                    regulation_id: nil,
                                    regulation_role: nil
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

      context 'with for different measure_type' do
        let(:second_measure_type) { create :measure_type }

        it { is_expected.not_to eq second_measure_type }
      end
    end
  end
end
