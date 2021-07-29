require 'rails_helper'

describe Api::V2::Measures::MeasureLegalActPresenter do
  subject(:presenter) { described_class.new(regulation) }

  let(:regulation) { create(:base_regulation, base_regulation_id: "1234567") }

  describe "#regulation_id" do
    it "should map to the models internal id" do
      expect(presenter.regulation_id).to eql(regulation.base_regulation_id)
    end
  end

  describe "published_date" do
    subject { presenter.published_date }

    context "without regulation present" do
      let(:legal_act) { nil }

      it { is_expected.to be_nil }
    end

    context "with legal act" do
      it { is_expected.to eql(regulation.published_date) }
    end
  end

  describe "#regulation_code" do
    let(:formatted_regulation_code) { "14567/23" }

    it { expect(presenter.regulation_code).to eql(formatted_regulation_code) }
  end

  describe "regulation_url" do
    let(:eu_regulation_url) { "http://eur-lex.europa.eu/search.html?" }

    it { expect(presenter.regulation_url).to start_with(eu_regulation_url) }
  end

  describe "#description" do
    it "should map to the regulations information text" do
      expect(presenter.description).to eql(regulation.information_text)
    end
  end

  context "when showing reduced information" do
    let(:regulation) { create(:base_regulation, base_regulation_id: 'IYY99990') }

    it { is_expected.to have_attributes(regulation_code: '') }
    it { is_expected.to have_attributes(regulation_url: '') }
    it { is_expected.to have_attributes(description: nil) }
  end
end
