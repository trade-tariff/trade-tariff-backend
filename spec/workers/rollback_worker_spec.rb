require "rails_helper"

describe RollbackWorker, type: :worker do
  before do
    allow($stdout).to receive(:write)
  end

  let(:date) { "01-01-2020" }

  describe "#perfomr" do
    context "for all envs" do
      before do
        allow(PaasConfig).to receive(:space).and_return("test")
      end

      it "invokes rollback" do
        expect(TariffSynchronizer).to receive(:rollback).with(date, false)
        expect(TariffSynchronizer).not_to receive(:rollback_cds)
        described_class.new.perform(date)
      end
    end

    context "for cds env" do
      before do
        allow(TradeTariffBackend).to receive(:use_cds?).and_return(true)
      end

      it "invokes rollback_cds" do
        expect(TariffSynchronizer).to receive(:rollback_cds).with(date, false)
        expect(TariffSynchronizer).not_to receive(:rollback)
        described_class.new.perform(date)
      end
    end
  end
end
