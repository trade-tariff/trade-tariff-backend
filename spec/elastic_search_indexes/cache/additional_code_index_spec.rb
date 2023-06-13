require 'rails_helper'

RSpec.describe Cache::AdditionalCodeIndex do
  subject(:instance) { described_class.new 'testnamespace' }

  describe '#dataset' do
    subject(:dataset) { instance.dataset }

    around { |example| TimeMachine.now { example.run } }

    let(:additional_code) { create(:additional_code) }

    before do
      goods_nomenclature = create(:heading)

      create(
        :measure,
        :with_base_regulation,
        additional_code_sid: additional_code.additional_code_sid,
        additional_code_type_id: additional_code.additional_code_type_id,
        additional_code_id: additional_code.additional_code,
        goods_nomenclature_sid: goods_nomenclature.goods_nomenclature_sid,
        goods_nomenclature_item_id: goods_nomenclature.goods_nomenclature_item_id,
      )

      # Non current additional code
      code = create(:additional_code, validity_end_date: Time.zone.yesterday)

      create(
        :measure,
        :with_base_regulation,
        additional_code_sid: code.additional_code_sid,
        additional_code_type_id: code.additional_code_type_id,
        additional_code_id: code.additional_code,
        goods_nomenclature_sid: goods_nomenclature.goods_nomenclature_sid,
        goods_nomenclature_item_id: goods_nomenclature.goods_nomenclature_item_id,
      )

      # No goods nomenclature
      code = create(:additional_code)

      create(
        :measure,
        :with_base_regulation,
        additional_code_sid: code.additional_code_sid,
        additional_code_type_id: code.additional_code_type_id,
        additional_code_id: code.additional_code,
        goods_nomenclature_sid: nil,
        goods_nomenclature_item_id: nil,
      )

      # Non current measure
      code = create(:additional_code)

      create(
        :measure,
        :with_base_regulation,
        additional_code_sid: code.additional_code_sid,
        additional_code_type_id: code.additional_code_type_id,
        additional_code_id: code.additional_code,
        goods_nomenclature_sid: goods_nomenclature.goods_nomenclature_sid,
        goods_nomenclature_item_id: goods_nomenclature.goods_nomenclature_item_id,
        validity_end_date: Time.zone.yesterday,
      )

      # Excluded type
      code = create(:additional_code, additional_code_type_id: '6')

      create(
        :measure,
        :with_base_regulation,
        additional_code_sid: code.additional_code_sid,
        additional_code_type_id: code.additional_code_type_id,
        additional_code_id: code.additional_code,
        goods_nomenclature_sid: goods_nomenclature.goods_nomenclature_sid,
        goods_nomenclature_item_id: goods_nomenclature.goods_nomenclature_item_id,
      )

      # Non-approved measure
      create(
        :measure,
        :with_unapproved_base_regulation,
        additional_code_sid: additional_code.additional_code_sid,
        additional_code_type_id: additional_code.additional_code_type_id,
        additional_code_id: additional_code.additional_code,
        goods_nomenclature_sid: goods_nomenclature.goods_nomenclature_sid,
        goods_nomenclature_item_id: goods_nomenclature.goods_nomenclature_item_id,
      )
    end

    it { expect(dataset.count).to eq 1 }
    it { expect(dataset).to all be_a AdditionalCode }
    it { expect(dataset.first.additional_code_sid).to eq additional_code.additional_code_sid }
  end

  it { is_expected.to have_attributes type: 'additional_code' }
  it { is_expected.to have_attributes name: 'testnamespace-additional_codes-uk-cache' }
  it { is_expected.to have_attributes name_without_namespace: 'AdditionalCodeIndex' }
  it { is_expected.to have_attributes model_class: AdditionalCode }
  it { is_expected.to have_attributes serializer: Cache::AdditionalCodeSerializer }

  describe '#serialize_record' do
    subject { instance.serialize_record record }

    let(:record) { create :additional_code, :with_description }

    it { is_expected.to include additional_code_sid: record.additional_code_sid }
  end
end
