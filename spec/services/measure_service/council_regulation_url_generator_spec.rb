RSpec.describe MeasureService::CouncilRegulationUrlGenerator do
  let(:service) { described_class.new(target_regulation) }

  def verify_citation_for(regulation_id)
    stub_const(
      'MeasureService::CouncilRegulationUrlGenerator::OJ_CITATION_VERIFIED',
      MeasureService::CouncilRegulationUrlGenerator::OJ_CITATION_VERIFIED | [regulation_id],
    )
  end

  describe '#generate' do
    context 'with a partial temporary stop regulation (no published date)' do
      let(:target_regulation) { create(:measure_partial_temporary_stop, partial_temporary_stop_regulation_id: 'A09CDEF') }

      it 'falls back to the sector 3 CELEX url' do
        code = '32009ACDEF'
        expect(service.generate).to eq("https://eur-lex.europa.eu/legal-content/EN/TXT/?uri=CELEX%3A#{code}")
      end

      it 'handles years that are greater than 2071' do
        target_regulation.partial_temporary_stop_regulation_id = 'A72CDEF'
        code = '31972ACDEF'
        expect(service.generate).to eq("https://eur-lex.europa.eu/legal-content/EN/TXT/?uri=CELEX%3A#{code}")
      end
    end

    context 'with an ordinary regulation (R prefix)' do
      let(:target_regulation) do
        create(:base_regulation,
               base_regulation_id: 'R2300990',
               officialjournal_number: 'L 10',
               officialjournal_page: 1,
               published_date: Date.new(2023, 1, 12))
      end

      it 'uses the sector 3 CELEX url even when OJ metadata is present' do
        expect(service.generate).to eq('https://eur-lex.europa.eu/legal-content/EN/TXT/?uri=CELEX%3A32023R0099')
      end
    end

    context 'with a sector 2 decision with complete OJ metadata' do
      let(:target_regulation) do
        create(:base_regulation,
               base_regulation_id: 'D9601421',
               officialjournal_number: 'L 35',
               officialjournal_page: 1,
               published_date: Date.new(1996, 2, 13))
      end

      it 'links by OJ citation, as DDS2-TARIC does' do
        expect(service.generate).to eq('https://eur-lex.europa.eu/legal-content/EN/TXT/?uri=uriserv%3AOJ.L_.1996.035.01.0001.01.ENG')
      end
    end

    context 'with a C series national dumping notice' do
      let(:target_regulation) do
        create(:base_regulation,
               base_regulation_id: 'I0000941',
               officialjournal_number: 'C 94',
               officialjournal_page: 2,
               published_date: Date.new(2000, 4, 1))
      end

      it 'links by OJ citation in the C series' do
        expect(service.generate).to eq('https://eur-lex.europa.eu/legal-content/EN/TXT/?uri=uriserv%3AOJ.C_.2000.094.01.0002.01.ENG')
      end
    end

    context 'with a modification regulation' do
      before { verify_citation_for 'D9708120' }

      let(:target_regulation) do
        create(:modification_regulation,
               modification_regulation_id: 'D9708120',
               officialjournal_number: 'L 334',
               officialjournal_page: 37,
               published_date: Date.new(1997, 12, 5))
      end

      it 'links by OJ citation' do
        expect(service.generate).to eq('https://eur-lex.europa.eu/legal-content/EN/TXT/?uri=uriserv%3AOJ.L_.1997.334.01.0037.01.ENG')
      end
    end

    context 'with a full temporary stop regulation' do
      before { verify_citation_for 'D9505100' }

      let(:target_regulation) do
        create(:fts_regulation,
               full_temporary_stop_regulation_id: 'D9505100',
               officialjournal_number: 'L 297',
               officialjournal_page: 3,
               published_date: Date.new(1995, 12, 9))
      end

      it 'links by OJ citation' do
        expect(service.generate).to eq('https://eur-lex.europa.eu/legal-content/EN/TXT/?uri=uriserv%3AOJ.L_.1995.297.01.0003.01.ENG')
      end
    end

    context 'with a decision not yet verified against EUR-Lex' do
      let(:target_regulation) do
        create(:base_regulation,
               base_regulation_id: 'D0206020',
               officialjournal_number: 'L 195',
               officialjournal_page: 38,
               published_date: Date.new(2002, 7, 24))
      end

      it 'keeps the sector 3 CELEX url until the audit verifies its citation' do
        expect(service.generate).to eq('https://eur-lex.europa.eu/legal-content/EN/TXT/?uri=CELEX%3A32002D0602')
      end
    end

    context 'with an unverified notice, which has no working CELEX link to lose' do
      let(:target_regulation) do
        create(:base_regulation,
               base_regulation_id: 'I7700010',
               officialjournal_number: 'C 200',
               officialjournal_page: 5,
               published_date: Date.new(1977, 8, 20))
      end

      it 'links by OJ citation by default' do
        expect(service.generate).to eq('https://eur-lex.europa.eu/legal-content/EN/TXT/?uri=uriserv%3AOJ.C_.1977.200.01.0005.01.ENG')
      end
    end

    context 'with a notice whose citation is known to be missing from EUR-Lex' do
      let(:target_regulation) do
        create(:base_regulation,
               base_regulation_id: 'I9902620',
               officialjournal_number: 'C 262',
               officialjournal_page: 6,
               published_date: Date.new(1999, 9, 16))
      end

      it 'keeps the sector 3 CELEX url' do
        expect(service.generate).to eq('https://eur-lex.europa.eu/legal-content/EN/TXT/?uri=CELEX%3A31999I0262')
      end
    end

    context 'with an OJ number containing extra spacing' do
      let(:target_regulation) do
        create(:base_regulation,
               base_regulation_id: 'I0000620',
               officialjournal_number: 'C  62',
               officialjournal_page: 19,
               published_date: Date.new(2000, 3, 4))
      end

      it 'parses the series and number' do
        expect(service.generate).to eq('https://eur-lex.europa.eu/legal-content/EN/TXT/?uri=uriserv%3AOJ.C_.2000.062.01.0019.01.ENG')
      end
    end

    context 'with a decision published after the OJ moved to act-by-act publication' do
      before { verify_citation_for 'D2412790' }

      let(:target_regulation) do
        create(:base_regulation,
               base_regulation_id: 'D2412790',
               officialjournal_number: 'L 12',
               officialjournal_page: 1,
               published_date: Date.new(2024, 5, 3))
      end

      it 'uses the sector 3 CELEX url, which post-2023 sequential numbering makes derivable' do
        expect(service.generate).to eq('https://eur-lex.europa.eu/legal-content/EN/TXT/?uri=CELEX%3A32024D1279')
      end

      it 'falls back on the cutoff date itself' do
        target_regulation.published_date = Date.new(2023, 10, 1)
        expect(service.generate).to eq('https://eur-lex.europa.eu/legal-content/EN/TXT/?uri=CELEX%3A32024D1279')
      end

      it 'links by OJ citation on the day before the cutoff' do
        target_regulation.published_date = Date.new(2023, 9, 30)
        expect(service.generate).to eq('https://eur-lex.europa.eu/legal-content/EN/TXT/?uri=uriserv%3AOJ.L_.2023.012.01.0001.01.ENG')
      end
    end

    context 'with an OJ number outside the L and C series' do
      let(:target_regulation) do
        create(:base_regulation,
               base_regulation_id: 'J1801440',
               officialjournal_number: 'J 144',
               officialjournal_page: 1,
               published_date: Date.new(2019, 3, 28))
      end

      it 'falls back to the sector 3 CELEX url' do
        expect(service.generate).to eq('https://eur-lex.europa.eu/legal-content/EN/TXT/?uri=CELEX%3A32018J0144')
      end
    end

    context 'with an OJ number carrying a series suffix' do
      let(:target_regulation) do
        create(:base_regulation,
               base_regulation_id: 'D9601421',
               officialjournal_number: 'L 35 E',
               officialjournal_page: 1,
               published_date: Date.new(1996, 2, 13))
      end

      it 'falls back to the sector 3 CELEX url' do
        expect(service.generate).to eq('https://eur-lex.europa.eu/legal-content/EN/TXT/?uri=CELEX%3A31996D0142')
      end
    end

    context 'with an OJ number without a space' do
      let(:target_regulation) do
        create(:base_regulation,
               base_regulation_id: 'D9601380',
               officialjournal_number: 'L32',
               officialjournal_page: 28,
               published_date: Date.new(1996, 2, 10))
      end

      it 'parses the series and number' do
        expect(service.generate).to eq('https://eur-lex.europa.eu/legal-content/EN/TXT/?uri=uriserv%3AOJ.L_.1996.032.01.0028.01.ENG')
      end
    end

    context 'with a document whose OJ citation is missing from EUR-Lex' do
      let(:target_regulation) do
        create(:base_regulation,
               base_regulation_id: 'D9600550',
               officialjournal_number: 'L 12',
               officialjournal_page: 11,
               published_date: Date.new(1996, 1, 17))
      end

      it 'keeps the working sector 3 CELEX url' do
        expect(service.generate).to eq('https://eur-lex.europa.eu/legal-content/EN/TXT/?uri=CELEX%3A31996D0055')
      end
    end

    context 'with only the OJ page missing' do
      let(:target_regulation) do
        create(:base_regulation,
               base_regulation_id: 'D9601421',
               officialjournal_number: 'L 35',
               officialjournal_page: nil,
               published_date: Date.new(1996, 2, 13))
      end

      it 'falls back to the sector 3 CELEX url' do
        expect(service.generate).to eq('https://eur-lex.europa.eu/legal-content/EN/TXT/?uri=CELEX%3A31996D0142')
      end
    end

    context 'with a decision missing OJ metadata' do
      let(:target_regulation) do
        create(:base_regulation,
               base_regulation_id: 'D9601421',
               officialjournal_number: nil,
               officialjournal_page: nil,
               published_date: Date.new(1996, 2, 13))
      end

      it 'falls back to the sector 3 CELEX url' do
        expect(service.generate).to eq('https://eur-lex.europa.eu/legal-content/EN/TXT/?uri=CELEX%3A31996D0142')
      end
    end

    context 'with an unparseable OJ number' do
      let(:target_regulation) do
        create(:base_regulation,
               base_regulation_id: 'D9601421',
               officialjournal_number: '1',
               officialjournal_page: 1,
               published_date: Date.new(1996, 2, 13))
      end

      it 'falls back to the sector 3 CELEX url' do
        expect(service.generate).to eq('https://eur-lex.europa.eu/legal-content/EN/TXT/?uri=CELEX%3A31996D0142')
      end
    end

    context 'with a zero OJ page' do
      let(:target_regulation) do
        create(:base_regulation,
               base_regulation_id: 'D9601421',
               officialjournal_number: 'L 35',
               officialjournal_page: 0,
               published_date: Date.new(1996, 2, 13))
      end

      it 'falls back to the sector 3 CELEX url' do
        expect(service.generate).to eq('https://eur-lex.europa.eu/legal-content/EN/TXT/?uri=CELEX%3A31996D0142')
      end
    end
  end
end
