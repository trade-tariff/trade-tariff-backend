require 'rails_helper'

RSpec.describe UkRegulationParser do
  subject(:parser) { described_class.new(information_text) }

  let(:information_text) do
    "The Leghold Trap and Pelt Imports (Amendment etc.) (EU Exit) Regulations 2019\xC2\xA0S.I. 2019/16\xC2\xA0https://www.legislation.gov.uk/uksi/2019/16"
  end

  describe "#regulation_code" do
    subject { parser.regulation_code }

    it { is_expected.to eql('S.I. 2019/16') }
  end

  describe "#regulation_url" do
    subject { parser.regulation_url }

    it { is_expected.to eql('https://www.legislation.gov.uk/uksi/2019/16') }
  end

  describe "#description" do
    subject { parser.description }

    it { is_expected.to eql('The Leghold Trap and Pelt Imports (Amendment etc.) (EU Exit) Regulations 2019') }
  end
end
