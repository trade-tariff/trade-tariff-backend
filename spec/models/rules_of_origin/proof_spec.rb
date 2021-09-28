require 'rails_helper'

RSpec.describe RulesOfOrigin::Proof do
  describe 'attributes' do
    it { is_expected.to respond_to :scheme }
    it { is_expected.to respond_to :summary }
    it { is_expected.to respond_to :detail }
    it { is_expected.to respond_to :proof_class }
    it { is_expected.to respond_to :subtext }
  end

  describe '.new' do
    subject do
      described_class.new \
        'summary' => 'Proof summary',
        'detail' => 'detail.md',
        'proof_class' => 'origin-declaration',
        'subtext' => 'subtext'
    end

    it { is_expected.to have_attributes summary: 'Proof summary' }
    it { is_expected.to have_attributes detail: 'detail.md' }
    it { is_expected.to have_attributes proof_class: 'origin-declaration' }
    it { is_expected.to have_attributes subtext: 'subtext' }
  end
end
