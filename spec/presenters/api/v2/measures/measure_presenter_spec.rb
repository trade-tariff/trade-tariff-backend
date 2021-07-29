require 'rails_helper'

describe Api::V2::Measures::MeasurePresenter do
  subject(:presenter) { described_class.new(measure, measure.goods_nomenclature) }

  let(:measure) { create(:measure) }

  describe "#legal_acts" do
    it "will be mapped through the MeasureLegalActPresenter" do
      expect(presenter.legal_acts.first).to \
        be_instance_of(Api::V2::Measures::MeasureLegalActPresenter)
    end
  end
end
