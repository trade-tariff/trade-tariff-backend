require 'rails_helper'

describe Footnote do
  describe 'associations' do
    describe 'additional code description' do
      let!(:footnote) { create :footnote }
      let!(:footnote_description_2) do
        create :footnote_description, :with_period,
               footnote_id: footnote.footnote_id,
               footnote_type_id: footnote.footnote_type_id,
               valid_at: 2.years.ago,
               valid_to: nil
      end
      let!(:footnote_description_3) do
        create :footnote_description, :with_period,
               footnote_id: footnote.footnote_id,
               footnote_type_id: footnote.footnote_type_id,
               valid_at: 5.years.ago,
               valid_to: 3.years.ago
      end

      context 'direct loading' do
        it 'loads correct description respecting given actual time' do
          TimeMachine.now do
            expect(
              footnote.footnote_description.pk,
            ).to eq footnote_description_2.pk
          end
        end

        it 'loads correct description respecting given time' do
          TimeMachine.at(4.years.ago) do
            expect(
              footnote.reload.footnote_description.pk,
            ).to eq footnote_description_3.pk
          end
        end
      end

      context 'eager loading' do
        it 'loads correct description respecting given actual time' do
          TimeMachine.now do
            expect(
              described_class.where(footnote_id: footnote.footnote_id,
                                    footnote_type_id: footnote.footnote_type_id)
                          .eager(:footnote_descriptions)
                          .all
                          .first
                          .footnote_description.pk,
            ).to eq footnote_description_2.pk
          end
        end

        it 'loads correct description respecting given time' do
          TimeMachine.at(4.years.ago) do
            expect(
              described_class.where(footnote_id: footnote.footnote_id,
                                    footnote_type_id: footnote.footnote_type_id)
                          .eager(:footnote_descriptions)
                          .all
                          .first
                          .footnote_description.pk,
            ).to eq footnote_description_3.pk
          end
        end
      end
    end
  end

  describe '#code' do
    let(:footnote) { build :footnote }

    it 'returns conjuction of footnote type id and footnote id' do
      expect(footnote.code).to eq [footnote.footnote_type_id, footnote.footnote_id].join
    end
  end
end
