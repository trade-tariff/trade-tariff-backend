RSpec.describe GeographicalArea do
  describe 'associations' do
    describe 'geographical area description' do
      let!(:geographical_area)                { create :geographical_area }
      let!(:geographical_area_description1)   do
        create :geographical_area_description, :with_period,
               geographical_area_sid: geographical_area.geographical_area_sid,
               valid_at: 3.years.ago,
               valid_to: nil
      end
      let!(:geographical_area_description2) do
        create :geographical_area_description, :with_period,
               geographical_area_sid: geographical_area.geographical_area_sid,
               valid_at: 5.years.ago,
               valid_to: 3.years.ago
      end

      context 'direct loading' do
        it 'loads correct description respecting given actual time' do
          TimeMachine.now do
            expect(
              geographical_area.geographical_area_description.pk,
            ).to eq geographical_area_description1.pk
          end
        end

        it 'loads correct description respecting given time' do
          TimeMachine.at(4.years.ago) do
            expect(
              geographical_area.reload.geographical_area_description.pk,
            ).to eq geographical_area_description2.pk
          end
        end
      end

      context 'eager loading' do
        it 'loads correct description respecting given actual time' do
          TimeMachine.now do
            expect(
              described_class.where(geographical_area_sid: geographical_area.geographical_area_sid)
                          .eager(:geographical_area_descriptions)
                          .first
                          .geographical_area_description.pk,
            ).to eq geographical_area_description1.pk
          end
        end

        it 'loads correct description respecting given time' do
          TimeMachine.at(1.year.ago) do
            result = described_class.eager(:geographical_area_descriptions)
                      .where(geographical_area_sid: geographical_area.geographical_area_sid)
                      .first.geographical_area_description.pk
            expect(result).to eq(geographical_area_description1.pk)
          end
        end

        it 'loads correct description respecting given time' do
          TimeMachine.at(4.years.ago) do
            result = described_class.where(geographical_area_sid: geographical_area.geographical_area_sid)
                      .eager(:geographical_area_descriptions)
                      .first.geographical_area_description.pk
            expect(result).to eq(geographical_area_description2.pk)
          end
        end
      end
    end

    describe 'contained geographical areas' do
      let!(:geographical_area)                { create :geographical_area, geographical_area_id: 'xx' }
      let!(:contained_area_present)           do
        create :geographical_area, geographical_area_id: 'ab',
                                   validity_start_date: 2.years.ago.beginning_of_day,
                                   validity_end_date: 2.years.ago.beginning_of_day
      end
      let!(:contained_area_past) do
        create :geographical_area, geographical_area_id: 'de',
                                   validity_start_date: 5.years.ago.beginning_of_day,
                                   validity_end_date: 3.years.ago
      end
      let!(:geographical_area_membership1) do
        create :geographical_area_membership, geographical_area_sid: contained_area_present.geographical_area_sid,
                                              geographical_area_group_sid: geographical_area.geographical_area_sid,
                                              validity_start_date: 2.years.ago.beginning_of_day,
                                              validity_end_date: nil
      end
      let!(:geographical_area_membership2) do
        create :geographical_area_membership, geographical_area_sid: contained_area_past.geographical_area_sid,
                                              geographical_area_group_sid: geographical_area.geographical_area_sid,
                                              validity_start_date: 5.years.ago.beginning_of_day,
                                              validity_end_date: 3.years.ago
      end

      context 'direct loading' do
        it 'loads correct description respecting given actual time' do
          TimeMachine.now do
            expect(
              geographical_area.contained_geographical_areas.map(&:pk),
            ).to include contained_area_present.pk
          end
        end

        it 'loads correct description respecting given time' do
          TimeMachine.at(4.years.ago) do
            expect(
              geographical_area.reload.contained_geographical_areas.map(&:pk),
            ).to include contained_area_past.pk
          end
        end
      end

      context 'eager loading' do
        it 'loads correct description respecting given actual time' do
          TimeMachine.now do
            expect(
              described_class.where(geographical_area_sid: geographical_area.geographical_area_sid)
                          .eager(:contained_geographical_areas)
                          .all
                          .first
                          .contained_geographical_areas
                          .map(&:pk),
            ).to include contained_area_present.pk
          end
        end

        it 'loads correct description respecting given time' do
          TimeMachine.at(4.years.ago) do
            expect(
              described_class.where(geographical_area_sid: geographical_area.geographical_area_sid)
                          .eager(:contained_geographical_areas)
                          .all
                          .first
                          .contained_geographical_areas
                          .map(&:pk),
            ).to include contained_area_past.pk
          end
        end
      end
    end
  end

  describe '#candidate_excluded_geographical_area_ids' do
    subject(:candidate_excluded_geographical_area_ids) do
      create(
        :geographical_area,
        :group,
        :with_members,
        geographical_area_id: '1011',
      ).candidate_excluded_geographical_area_ids
    end

    it { is_expected.to eq(%w[RO 1011]) }
  end

  describe '.referenced' do
    context 'when the geographical area is a reference area' do
      subject(:refeenced) { create(:geographical_area, geographical_area_id: 'EU').referenced }

      before do
        create(:geographical_area, geographical_area_id: '1013')
      end

      it { is_expected.to have_attributes(geographical_area_id: '1013') }
      it { is_expected.to be_a(described_class) }
    end

    context 'when the geographical area is not a reference area' do
      subject(:refeenced) { create(:geographical_area).referenced }

      it { is_expected.to be_nil }
    end
  end
end
