RSpec.describe TariffKnowledge::SyntheticAtar do
  describe 'validations' do
    subject(:synthetic_atar) { build(:tariff_knowledge_synthetic_atar, **attrs) }

    let(:attrs) { {} }

    it 'is valid with the factory defaults' do
      expect(synthetic_atar).to be_valid
    end

    %i[real_user_search description chapter goods_nomenclature_item_id].each do |column|
      context "when #{column} is blank" do
        let(:attrs) { { column => '' } }

        it 'is invalid' do
          expect(synthetic_atar).not_to be_valid
          expect(synthetic_atar.errors[column]).to be_present
        end
      end
    end

    context 'when the commodity code has only 9 digits (a leading zero was dropped)' do
      let(:attrs) { { goods_nomenclature_item_id: '101210000' } }

      it 'is invalid and the message mentions the leading zero' do
        expect(synthetic_atar).not_to be_valid
        expect(synthetic_atar.errors[:goods_nomenclature_item_id].join).to include('leading zero')
      end
    end

    context 'when the commodity code contains letters' do
      let(:attrs) { { goods_nomenclature_item_id: '39241000AB' } }

      it 'is invalid' do
        expect(synthetic_atar).not_to be_valid
      end
    end

    context 'when the chapter has one digit' do
      let(:attrs) { { chapter: '1' } }

      it 'is padded to two digits' do
        expect(synthetic_atar).to be_valid
        expect(synthetic_atar.chapter).to eq('01')
      end
    end

    context 'when the chapter has three digits' do
      let(:attrs) { { chapter: '123' } }

      it 'is invalid with a single message' do
        expect(synthetic_atar).not_to be_valid
        expect(synthetic_atar.errors[:chapter].size).to eq(1)
      end
    end

    context 'when the real user search has extra spaces' do
      let(:attrs) { { real_user_search: "  plastic   box \n" } }

      it 'is squished before validation' do
        expect(synthetic_atar).to be_valid
        expect(synthetic_atar.real_user_search).to eq('plastic box')
      end
    end

    context 'when optional text fields are blank strings' do
      let(:attrs) { { likely_heading: '', notes: '  ', completed_by: '' } }

      it 'stores them as nil' do
        expect(synthetic_atar).to be_valid
        expect(synthetic_atar.likely_heading).to be_nil
        expect(synthetic_atar.notes).to be_nil
        expect(synthetic_atar.completed_by).to be_nil
      end
    end

    context 'when another record has the same real user search in different case' do
      before { create(:tariff_knowledge_synthetic_atar, real_user_search: 'Plastic Box') }

      let(:attrs) { { real_user_search: ' plastic  box' } }

      it 'is invalid' do
        expect(synthetic_atar).not_to be_valid
        expect(synthetic_atar.errors[:real_user_search]).to include('is already used by another synthetic ATaR')
      end
    end

    context 'when the only record with that real user search is the record itself' do
      subject(:synthetic_atar) { create(:tariff_knowledge_synthetic_atar, real_user_search: 'plastic box') }

      it 'is still valid after an update' do
        synthetic_atar.set(notes: 'Changed note')

        expect(synthetic_atar).to be_valid
      end
    end
  end

  describe 'database constraints' do
    let(:columns) do
      {
        chapter: '39',
        real_user_search: 'plastic box',
        description: 'Plastic box',
        goods_nomenclature_item_id: '3924100000',
        created_at: Time.current,
        updated_at: Time.current,
      }
    end

    it 'rejects a duplicate real user search that differs only by case' do
      described_class.dataset.insert(columns)

      expect { described_class.dataset.insert(columns.merge(real_user_search: 'PLASTIC BOX')) }
        .to raise_error(Sequel::UniqueConstraintViolation)
    end

    it 'rejects a commodity code that is not 10 digits' do
      expect { described_class.dataset.insert(columns.merge(goods_nomenclature_item_id: '392410000')) }
        .to raise_error(Sequel::CheckConstraintViolation)
    end

    it 'rejects a chapter that is not 2 digits' do
      expect { described_class.dataset.insert(columns.merge(chapter: '3')) }
        .to raise_error(Sequel::CheckConstraintViolation)
    end
  end

  describe 'dataset methods' do
    let!(:box) { create(:tariff_knowledge_synthetic_atar, real_user_search: 'plastic box', chapter: '39') }
    let!(:saddle) do
      create(
        :tariff_knowledge_synthetic_atar,
        real_user_search: 'saddle',
        chapter: '42',
        description: 'Leather riding saddle for a pony.',
        goods_nomenclature_item_id: '4201000000',
      )
    end

    describe '.search' do
      it 'matches the real user search, ignoring case' do
        expect(described_class.search('PLASTIC').all).to eq([box])
      end

      it 'matches the description' do
        expect(described_class.search('riding').all).to eq([saddle])
      end

      it 'returns everything when the query is blank' do
        expect(described_class.search('').all).to contain_exactly(box, saddle)
      end
    end

    describe '.for_chapter' do
      it 'filters by chapter' do
        expect(described_class.for_chapter('42').all).to eq([saddle])
      end

      it 'pads a one digit chapter' do
        create(:tariff_knowledge_synthetic_atar, chapter: '01', goods_nomenclature_item_id: '0101210000')

        expect(described_class.for_chapter('1').count).to eq(1)
      end

      it 'returns everything when the chapter is blank' do
        expect(described_class.for_chapter(nil).count).to eq(2)
      end
    end

    describe '.by_real_user_search' do
      it 'finds a record regardless of case and spacing' do
        expect(described_class.by_real_user_search('  Plastic  BOX ').first).to eq(box)
      end
    end
  end

  describe 'blank optional values' do
    it 'are stored as nil when they are assigned' do
      synthetic_atar = described_class.new(notes: '  ', likely_heading: '', completed_by: nil)

      expect(synthetic_atar.values).to include(notes: nil, likely_heading: nil, completed_by: nil)
    end

    it 'do not count as a change when the column is already nil, so no version is written' do
      synthetic_atar = create(:tariff_knowledge_synthetic_atar, notes: nil, likely_heading: nil, completed_by: nil)

      expect { synthetic_atar.update(notes: '', likely_heading: ' ', completed_by: '') }
        .not_to(change { synthetic_atar.versions.count })
    end
  end

  describe 'versioning' do
    it 'records a create version and an update version with the editor' do
      TradeTariffRequest.whodunnit = 'user-123'
      synthetic_atar = create(:tariff_knowledge_synthetic_atar)

      expect { synthetic_atar.update(notes: 'Changed note') }
        .to change { synthetic_atar.versions.count }.from(1).to(2)

      expect(synthetic_atar.versions.map(&:event)).to eq(%w[create update])
      expect(synthetic_atar.versions.map(&:whodunnit).uniq).to eq(%w[user-123])
    ensure
      TradeTariffRequest.whodunnit = nil
    end

    it 'records a destroy version' do
      synthetic_atar = create(:tariff_knowledge_synthetic_atar)

      synthetic_atar.destroy

      versions = Version.where(item_type: 'TariffKnowledge::SyntheticAtar', item_id: synthetic_atar.id.to_s)
      expect(versions.map(:event)).to eq(%w[create destroy])
    end
  end
end
