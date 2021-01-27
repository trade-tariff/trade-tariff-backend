require 'rails_helper'

describe GeographicalArea do
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
                                   validity_start_date: Date.current.ago(2.years),
                                   validity_end_date: Date.current.ago(2.years)
      end
      let!(:contained_area_past) do
        create :geographical_area, geographical_area_id: 'de',
                                   validity_start_date: Date.current.ago(5.years),
                                   validity_end_date: 3.years.ago
      end
      let!(:geographical_area_membership1) do
        create :geographical_area_membership, geographical_area_sid: contained_area_present.geographical_area_sid,
                                              geographical_area_group_sid: geographical_area.geographical_area_sid,
                                              validity_start_date: Date.current.ago(2.years),
                                              validity_end_date: nil
      end
      let!(:geographical_area_membership2) do
        create :geographical_area_membership, geographical_area_sid: contained_area_past.geographical_area_sid,
                                              geographical_area_group_sid: geographical_area.geographical_area_sid,
                                              validity_start_date: Date.current.ago(5.years),
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
                          .contained_geographical_areas(reload: true)
                          .map(&:pk),
            ).to include contained_area_past.pk
          end
        end
      end
    end
  end

  describe 'validations' do
    # GA1 The combination geographical area id + validity start date must be unique.
    it { is_expected.to validate_uniqueness.of(%i[geographical_area_id validity_start_date]) }
    # GA2 The start date must be less than or equal to the end date.
    it { is_expected.to validate_validity_dates }

    describe 'GA4' do
      let(:geographical_area) do
        build(:geographical_area, parent_geographical_area_group_sid: parent_id)
      end

      before { geographical_area.conformant? }

      context 'invalid parent id' do
        let(:parent_id) { '435' }

        it {
          expect(geographical_area.conformance_errors).to have_key(:GA4)
        }
      end

      context 'invalid area code' do
        let(:parent_id) do
          create(:geographical_area, :country).geographical_area_sid
        end

        it {
          expect(geographical_area.conformance_errors).to have_key(:GA4)
        }
      end

      context 'valid' do
        let(:parent_id) do
          create(:geographical_area, geographical_code: '1').geographical_area_sid
        end

        it {
          expect(geographical_area.conformance_errors).not_to have_key(:GA4)
        }
      end
    end

    describe 'GA5' do
      let(:geographical_area) do
        create(:geographical_area,
               validity_end_date: Date.current,
               validity_start_date: 3.years.ago,
               parent_geographical_area: parent)
      end

      before { geographical_area.conformant? }

      context 'invalid parent period' do
        context 'start date' do
          let(:parent) do
            create(:geographical_area, validity_start_date: Date.yesterday)
          end

          it {
            expect(geographical_area.conformance_errors).to have_key(:GA5)
          }
        end

        context 'end date' do
          let(:parent) do
            create(:geographical_area,
                   validity_end_date: Date.yesterday,
                   validity_start_date: 3.years.ago)
          end

          it {
            expect(geographical_area.conformance_errors).to have_key(:GA5)
          }
        end

        context 'without end date' do
          let(:parent) do
            create(:geographical_area,
                   validity_end_date: Date.current,
                   validity_start_date: 3.years.ago)
          end

          before do
            geographical_area.validity_end_date = nil
            geographical_area.conformant?
          end

          it {
            expect(geographical_area.conformance_errors).to have_key(:GA5)
          }
        end

        context 'with start_date after parent and no end date' do
          let(:parent) do
            create(:geographical_area,
                   validity_end_date: Date.current,
                   validity_start_date: 3.years.ago)
          end

          before do
            geographical_area.validity_start_date = Date.current.ago(2.years)
            geographical_area.validity_end_date = nil
            geographical_area.conformant?
          end

          it {
            expect(geographical_area.conformance_errors).to have_key(:GA5)
          }
        end
      end

      context 'valid' do
        context 'with end date' do
          let(:parent) do
            create(:geographical_area,
                   validity_end_date: Date.current,
                   validity_start_date: 3.years.ago)
          end

          it {
            expect(geographical_area.conformance_errors).not_to have_key(:GA5)
          }
        end

        context 'parent without end date' do
          let(:parent) do
            create(:geographical_area,
                   validity_end_date: nil,
                   validity_start_date: 3.years.ago)
          end

          it {
            expect(geographical_area.conformance_errors).not_to have_key(:GA5)
          }
        end

        context 'both without end dates' do
          let(:parent) do
            create(:geographical_area,
                   validity_end_date: nil,
                   validity_start_date: 3.years.ago)
          end

          before do
            geographical_area.validity_end_date = nil
            geographical_area.conformant?
          end

          it {
            expect(geographical_area.conformance_errors).not_to have_key(:GA5)
          }
        end
      end
    end

    describe 'GA6' do
      let(:geographical_area) { create(:geographical_area) }

      before do
        geographical_area.parent_geographical_area_group_sid = parent.geographical_area_sid
        geographical_area.conformant?
      end

      context 'direct loop between parent-children' do
        let!(:parent) do
          create(:geographical_area, parent_geographical_area_group_sid: geographical_area.geographical_area_sid)
        end

        it {
          expect(geographical_area.conformance_errors).to have_key(:GA6)
        }
      end

      context 'two-level loop between parent-children' do
        let!(:parent) do
          child = create(:geographical_area, parent_geographical_area_group_sid: geographical_area.geographical_area_sid)
          create(:geographical_area, parent_geographical_area_group_sid: child.geographical_area_sid)
        end

        it {
          expect(geographical_area.conformance_errors).to have_key(:GA6)
        }
      end
    end
  end
end
