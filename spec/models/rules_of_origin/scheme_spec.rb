require 'rails_helper'

RSpec.describe RulesOfOrigin::Scheme do
  describe 'attributes' do
    it { is_expected.to respond_to :scheme_code }
    it { is_expected.to respond_to :title }
    it { is_expected.to respond_to :introductory_notes_file }
    it { is_expected.to respond_to :fta_intro_file }
    it { is_expected.to respond_to :links }
    it { is_expected.to respond_to :explainers }
    it { is_expected.to respond_to :countries }
    it { is_expected.to respond_to :rule_offset }
    it { is_expected.to respond_to :footnote }
  end

  describe '#links=' do
    subject(:links) { instance.links }

    before { instance.links = links_data }

    let(:instance) { described_class.new }

    let(:links_data) do
      [
        { text: 'HMRC', url: 'https://www.hmrc.gov.uk' },
        { text: 'GovUK', url: 'https://www.gov.uk' },
        { text: '', url: '' },
      ]
    end

    it { is_expected.to have_attributes length: 2 }
    it { is_expected.to all be_instance_of RulesOfOrigin::Link }
    it { expect(links.first).to have_attributes text: 'HMRC' }
    it { expect(links.first).to have_attributes url: 'https://www.hmrc.gov.uk' }
  end
end
