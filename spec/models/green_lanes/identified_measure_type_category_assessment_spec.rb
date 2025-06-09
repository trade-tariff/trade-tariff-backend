require 'rails_helper'

RSpec.describe GreenLanes::IdentifiedMeasureTypeCategoryAssessment do
  describe 'attributes' do
    it { is_expected.to respond_to :measure_type_id }
    it { is_expected.to respond_to :theme_id }
    it { is_expected.to respond_to :created_at }
    it { is_expected.to respond_to :updated_at }
  end

  describe 'validations' do
    subject(:errors) { instance.tap(&:valid?).errors }

    let(:instance) { described_class.new }

    it { is_expected.to include measure_type_id: ['is not present'] }
    it { is_expected.to include theme_id: ['is not present'] }

    context 'with duplicate associations' do
      let(:existing) { create :identified_measure_type_category_assessment }

      let :instance do
        described_class.new measure_type_id: existing.measure_type_id
      end

      it { is_expected.to include measure_type_id: ['is already taken'] }
    end
  end

  describe 'date fields' do
    subject { create(:identified_measure_type_category_assessment).reload }

    it { is_expected.to have_attributes created_at: be_within(1.minute).of(Time.zone.now) }
    it { is_expected.to have_attributes updated_at: be_within(1.minute).of(Time.zone.now) }
  end
end
