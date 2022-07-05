require 'rails_helper'

RSpec.describe RulesOfOrigin::V2::Rule do
  it { is_expected.to respond_to :id }
  it { is_expected.to respond_to :rule }
  it { is_expected.to respond_to :original }
  it { is_expected.to respond_to :rule_class }
  it { is_expected.to respond_to :operator }

  describe '#rule_class' do
    subject { described_class.new(class: rule_class).rule_class }

    context 'without rule class' do
      let(:rule_class) { nil }

      it { is_expected.to be_empty }
    end

    context 'with blank rule class' do
      let(:rule_class) { '' }

      it { is_expected.to be_empty }
    end

    context 'with single rule class' do
      let(:rule_class) { 'AB' }

      it { is_expected.to eql %w[AB] }
    end

    context 'with multiple rule classes' do
      let(:rule_class) { %w[AB CD] }

      it { is_expected.to eql %w[AB CD] }
    end

    context 'with out of order rule classes' do
      let(:rule_class) { %w[CD AB] }

      it { is_expected.to eql %w[AB CD] }
    end
  end
end
