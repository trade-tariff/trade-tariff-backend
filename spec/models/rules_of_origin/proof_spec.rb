require 'rails_helper'

RSpec.describe RulesOfOrigin::Proof do
  describe 'attributes' do
    it { is_expected.to respond_to :scheme }
    it { is_expected.to respond_to :summary }
    it { is_expected.to respond_to :detail }
  end

  describe '.new' do
    subject do
      described_class.new 'summary' => 'Proof summary', 'detail' => 'detail.md'
    end

    it { is_expected.to have_attributes summary: 'Proof summary' }
    it { is_expected.to have_attributes detail: 'detail.md' }
  end
end
