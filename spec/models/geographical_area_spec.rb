RSpec.describe GeographicalArea do
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

  describe '#referenced' do
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

  describe '#referenced_or_self' do
    context 'with referenced' do
      subject(:referencer) { create :geographical_area, geographical_area_id: 'EU' }

      let(:reference) { create :geographical_area, geographical_area_id: '1013' }

      it { is_expected.to have_attributes referenced: reference }
      it { is_expected.to have_attributes referenced_or_self: referencer }
    end

    context 'without referenced' do
      subject(:referencer) { create :geographical_area, geographical_area_id: 'FR' }

      it { is_expected.to have_attributes referenced: nil }
      it { is_expected.to have_attributes referenced_or_self: referencer }
    end
  end

  describe '#gsp_or_dcts?' do
    context 'when geographical_area belongs to GSP least developed countries' do
      subject(:geographical_area) { create(:geographical_area, :with_gsp_least_developed_countries) }

      it { is_expected.to be_gsp_or_dcts }
    end

    context 'when geographical_area belongs to GSP general framework' do
      subject(:geographical_area) { create(:geographical_area, :with_gsp_general_framework) }

      it { is_expected.to be_gsp_or_dcts }
    end

    context 'when geographical_area belongs to GSP enhanced framework' do
      subject(:geographical_area) { create(:geographical_area, :with_gsp_enhanced_framework) }

      it { is_expected.to be_gsp_or_dcts }
    end

    context 'when geographical_area does not belong to GSP or DCTS country' do
      subject(:geographical_area) { create(:geographical_area) }

      it { is_expected.not_to be_gsp_or_dcts }
    end

    context 'when geographical_area belongs to DCTS Standard Preferences' do
      subject(:geographical_area) { create(:geographical_area, :with_dcts_standard_preferences) }

      it { is_expected.to be_gsp_or_dcts }
    end

    context 'when geographical_area belongs to DCTS Enhanced Preferences' do
      subject(:geographical_area) { create(:geographical_area, :with_dcts_enhanced_preferences) }

      it { is_expected.to be_gsp_or_dcts }
    end

    context 'when geographical_area belongs to DCTS Comprehensive Preferences' do
      subject(:geographical_area) { create(:geographical_area, :with_dcts_comprehensive_preferences) }

      it { is_expected.to be_gsp_or_dcts }
    end

    describe '.countries' do
      subject(:countries) { described_class.countries }

      before do
        create(:geographical_area, :country, geographical_area_id: 'RO')
        create(:geographical_area, :group, geographical_area_id: '1011')
      end

      it { is_expected.to have_attributes(count: 1) }
      it { is_expected.to all(have_attributes(geographical_area_id: 'RO')) }
    end

    describe '.groups' do
      subject(:groups) { described_class.groups }

      before do
        create(:geographical_area, :country, geographical_area_id: 'RO')
        create(:geographical_area, :group, geographical_area_id: '1011')
      end

      it { is_expected.to have_attributes(count: 1) }
      it { is_expected.to all(have_attributes(geographical_area_id: '1011')) }
    end

    describe '.areas' do
      subject(:areas) { described_class.areas }

      before do
        create(:geographical_area, :country, geographical_area_id: 'RO')
        create(:geographical_area, :group, geographical_area_id: '1011')
      end

      it { is_expected.to have_attributes(count: 2) }
    end
  end

  describe '.european_union_member_ids' do
    context 'when EU and its members exist' do
      subject(:member_ids) { described_class.european_union_member_ids }

      before do
        create(:geographical_area, geographical_area_id: 'EU')

        eu_group = create(:geographical_area, :group, geographical_area_id: '1013')

        fr = create(:geographical_area, :country, geographical_area_id: 'FR')
        de = create(:geographical_area, :country, geographical_area_id: 'DE')
        es = create(:geographical_area, :country, geographical_area_id: 'ES')

        create(:geographical_area_membership,
               geographical_area_sid: fr.geographical_area_sid,
               geographical_area_group_sid: eu_group.geographical_area_sid)
        create(:geographical_area_membership,
               geographical_area_sid: de.geographical_area_sid,
               geographical_area_group_sid: eu_group.geographical_area_sid)
        create(:geographical_area_membership,
               geographical_area_sid: es.geographical_area_sid,
               geographical_area_group_sid: eu_group.geographical_area_sid)
      end

      it 'returns the geographical_area_ids of all EU members' do
        expect(member_ids).to contain_exactly('FR', 'DE', 'ES')
      end
    end

    context 'when EU does not exist' do
      subject(:member_ids) { described_class.european_union_member_ids }

      it 'returns an empty array' do
        expect(member_ids).to eq([])
      end
    end

    context 'when EU exists but has no referenced area' do
      subject(:member_ids) { described_class.european_union_member_ids }

      before do
        create(:geographical_area, geographical_area_id: 'EU')
      end

      it 'returns an empty array' do
        expect(member_ids).to eq([])
      end
    end
  end
end
