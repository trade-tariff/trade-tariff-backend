require 'rails_helper'

describe Api::V2::Measures::MeasureLegalActPresenter do
  subject(:presenter) { described_class.new(regulation, measure) }

  let(:regulation) { create(:base_regulation, base_regulation_id: "1234567") }
  let(:measure) { create(:measure) }

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

  context "for XI service" do
    before { allow(TradeTariffBackend).to receive(:service).and_return('xi') }

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
  end

  context "for UK service" do
    before { allow(TradeTariffBackend).to receive(:service).and_return('uk') }

    context "if before 01 Jan 2021" do
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
    end

    context "if after 01 Jan 2021" do
      let(:regulation) { create(:base_regulation, :uk_concatenated_regulation) }

      describe "#regulation_code" do
        it { expect(presenter.regulation_code).to eql('S.I. 2019/16') }
      end

      describe "#regulation_url" do
        let(:uk_regulation_url) { 'https://www.legislation.gov.uk/uksi/2019/16' }

        it { expect(presenter.regulation_url).to eql(uk_regulation_url) }
      end

      describe "#description" do
        let(:uk_description) { 'The Leghold Trap and Pelt Imports (Amendment etc.) (EU Exit) Regulations 2019' }

        it { expect(presenter.description).to eql(uk_description) }
      end
    end
  end

  context "when showing reduced information" do
    context "with regulation id of IVY99990" do
      let(:regulation) { create(:base_regulation, base_regulation_id: 'IYY99990') }

      it { is_expected.to have_attributes(regulation_code: '') }
      it { is_expected.to have_attributes(regulation_url: '') }
      it { is_expected.to have_attributes(description: nil) }
    end

    context "with measure type 305" do
      let(:measure) { create(:measure, measure_type_id: '305') }

      it { is_expected.to have_attributes(regulation_code: '') }
      it { is_expected.to have_attributes(regulation_url: '') }
      it { is_expected.to have_attributes(description: nil) }
    end

    context "with measure type 306" do
      let(:measure) { create(:measure, measure_type_id: '306') }

      it { is_expected.to have_attributes(regulation_code: '') }
      it { is_expected.to have_attributes(regulation_url: '') }
      it { is_expected.to have_attributes(description: nil) }
    end
  end
end
