require 'rails_helper'

RSpec.describe GreenLanes::UpdateNotification do
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
  end

  describe 'validations' do
    subject(:errors) { instance.tap(&:valid?).errors }

    let(:instance) { described_class.new }

    it { is_expected.to include measure_type_id: ['is not present'] }
  end

  describe 'date fields' do
    subject { create(:category_assessment).reload }

    it { is_expected.to have_attributes created_at: be_within(1.minute).of(Time.zone.now) }
    it { is_expected.to have_attributes updated_at: be_within(1.minute).of(Time.zone.now) }
  end

  describe 'associations' do
    describe '#theme' do
      subject { notification.reload.theme }

      let(:notification) { create :update_notification, theme: }
      let(:theme) { create :green_lanes_theme }

      it { is_expected.to eq theme }

      context 'with for different theme' do
        let(:second_theme) { create :green_lanes_theme }

        it { is_expected.not_to eq second_theme }
      end
    end

    describe '#measure_type' do
      subject { notification.reload.measure_type }

      let(:notification) { create :update_notification, measure_type: }
      let(:measure_type) { create :measure_type }

      it { is_expected.to eq measure_type }

      context 'with different measure_type' do
        let(:second_measure_type) { create :measure_type }

        it { is_expected.not_to eq second_measure_type }
      end
    end

    describe '#base_regulation' do
      subject { notification.reload.base_regulation }

      let(:notification) { create :update_notification, base_regulation: }
      let(:base_regulation) { create :base_regulation }

      it { is_expected.to eq base_regulation }

      context 'with different base_regulation' do
        let(:second_regulation) { create :base_regulation }

        it { is_expected.not_to eq second_regulation }
      end
    end

    describe '#modification_regulation' do
      subject { notification.reload.modification_regulation }

      let(:notification) { create :update_notification, modification_regulation: }
      let(:modification_regulation) { create :modification_regulation }

      it { is_expected.to eq modification_regulation }

      context 'with different modification_regulation' do
        let(:second_regulation) { create :modification_regulation }

        it { is_expected.not_to eq second_regulation }
      end
    end
  end

  describe '#regulation' do
    subject { notification.reload.regulation }

    let :notification do
      create :update_notification, regulation_id: regulation&.regulation_id,
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
    subject { notification }

    before { notification.regulation = new_regulation }

    let(:persisted) { notification.tap(&:save).reload }
    let(:regulation) { create :base_regulation }

    let :notification do
      create :update_notification, regulation_id: regulation&.regulation_id,
                                   regulation_role: regulation&.role
    end

    context 'with modification regulation' do
      let(:new_regulation) { create :modification_regulation }

      it { is_expected.to have_attributes base_regulation: nil }
      it { is_expected.to have_attributes modification_regulation: new_regulation }

      it 'is updates relationship attributes' do
        expect(notification).to have_attributes regulation_id: new_regulation.regulation_id,
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
        expect(notification).to have_attributes regulation_id: new_regulation.regulation_id,
                                                regulation_role: new_regulation.role
      end

      it 'is is still updated after save and reload' do
        expect(persisted).to have_attributes regulation_id: new_regulation.regulation_id,
                                             regulation_role: new_regulation.role
      end
    end
  end
end
