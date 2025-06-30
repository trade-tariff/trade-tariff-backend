RSpec.describe RulesOfOrigin::Explainer do
  describe 'attributes' do
    it { is_expected.to respond_to :text }
    it { is_expected.to respond_to :url }
  end

  describe '.new' do
    subject do
      described_class.new 'text' => 'More information', 'url' => 'explanation.md'
    end

    it { is_expected.to have_attributes text: 'More information' }
    it { is_expected.to have_attributes url: 'explanation.md' }
  end

  describe '.new_with_check' do
    subject(:explainer) { described_class.new_with_check data }

    context 'with valid' do
      let(:data) { { 'text' => 'GovUK', 'url' => 'govuk.md' } }

      it { is_expected.to be_instance_of described_class }
    end

    context 'with partially valid' do
      let(:data) { { 'text' => 'GovUK', 'url' => '' } }

      it { is_expected.to be_nil }
    end

    context 'with invalid' do
      let(:data) { { 'text' => '', 'url' => '' } }

      it { is_expected.to be_nil }
    end
  end
end
