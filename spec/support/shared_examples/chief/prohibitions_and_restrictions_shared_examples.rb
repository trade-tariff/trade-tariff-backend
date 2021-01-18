shared_examples_for 'P&R Daily Update TAME and TAMF Daily Scenario 1: Changed country group for measure outcome' do
  before { ChiefTransformer.instance.invoke }

  it 'creates one extra measure' do
    expect(Measure.count).to eq 7
  end

  it 'ends the existing measure' do
    m = Measure.where(goods_nomenclature_item_id: '2106909829',
                      validity_start_date: DateTime.parse('2008-04-01 00:00:00'),
                      validity_end_date: DateTime.parse('2008-05-01 00:00:00')).take
  end

  it 'creates a new measure for 2106909829' do
    m = Measure.where(goods_nomenclature_item_id: '2106909829',
                      validity_start_date: DateTime.parse('2008-04-01 00:00:00')).take
    expect(m[:geographical_area_id]).to eq '1011'
    expect(m.measure_conditions.count).to eq 2
  end

  it 'creates measure conditions for new measure for 2106909829' do
    m = Measure.where(goods_nomenclature_item_id: '2106909829',
                      validity_start_date: DateTime.parse('2008-04-01 00:00:00')).take
    expect(
      m.measure_conditions_dataset.where(condition_code: 'B',
                                         component_sequence_number: 1,
                                         certificate_type_code: 'N',
                                         certificate_code: '853').any?,
    ).to be_truthy
    expect(
      m.measure_conditions_dataset.where(condition_code: 'B',
                                         component_sequence_number: 2,
                                         action_code: '04').any?,
    ).to be_truthy
  end

  it 'creates footnote associationf or new measure for 2106909829' do
    m = Measure.where(goods_nomenclature_item_id: '2106909829',
                      validity_start_date: DateTime.parse('2008-04-01 00:00:00')).take
    expect(
      m.footnote_association_measures_dataset.where(footnote_type_id: '04',
                                                    footnote_id: '006').any?,
    ).to be_truthy
  end
end

shared_examples_for 'P&R Daily Update TAME and TAMF Daily Scenario 2: Restriction removed outcome' do
  before { ChiefTransformer.instance.invoke }

  it 'does not create new measures' do
    expect(Measure.count).to eq 6
  end

  it 'ends all the measures that are applicable' do
    m1 = Measure.where(goods_nomenclature_item_id: '9706000000',
                       validity_start_date: DateTime.parse('2008-04-01 00:00:00'),
                       validity_end_date: DateTime.parse('2008-05-31 17:50:00')).take
    m2 = Measure.where(goods_nomenclature_item_id: '9706000010',
                       validity_start_date: DateTime.parse('2008-04-01 00:00:00'),
                       validity_end_date: DateTime.parse('2008-05-31 17:50:00')).take
    m3 = Measure.where(goods_nomenclature_item_id: '9706000090',
                       validity_start_date: DateTime.parse('2008-04-01 00:00:00'),
                       validity_end_date: DateTime.parse('2008-05-31 17:50:00')).take
  end
end

shared_examples_for 'P&R Daily Update TAME and TAMF Daily Scenario 3: Country group changed countries outcome' do
  before { ChiefTransformer.instance.invoke }

  it 'creates three new measures' do
    expect(Measure.count).to eq 9
  end

  it 'ends the old measures' do
    m1 = Measure.where(goods_nomenclature_item_id: '2106909829',
                       geographical_area_sid: 400,
                       validity_start_date: DateTime.parse('2008-04-01 00:00:00')).take
    expect(m1.validity_end_date).not_to be_nil # should be new start date - 1 sec
  end

  it 'creates a measure for us' do
    m1 = Measure.where(goods_nomenclature_item_id: '2106909829',
                       geographical_area_sid: 103,
                       validity_start_date: DateTime.parse('2008-05-01 00:00:00')).take
  end

  it 'creates a measure for cn' do
    m1 = Measure.where(goods_nomenclature_item_id: '2106909829',
                       geographical_area_sid: 439,
                       validity_start_date: DateTime.parse('2008-05-01 00:00:00')).take
  end

  it 'creates a measure for iq' do
    m1 = Measure.where(goods_nomenclature_item_id: '2106909829',
                       geographical_area_sid: -2,
                       validity_start_date: DateTime.parse('2008-05-01 00:00:00')).take
  end
end

shared_examples_for 'P&R Daily Update MFCM Daily Scenario 1: Restriction removed for measure outcome' do
  before { ChiefTransformer.instance.invoke }

  it 'creates no new measures' do
    expect(Measure.count).to eq 6
  end

  it 'set the end date on the measure' do
    m1 = Measure.where(goods_nomenclature_item_id: '1210100010',
                       validity_start_date: DateTime.parse('2008-04-01 00:00:00'),
                       validity_end_date: DateTime.parse('2008-04-30 15:00:00')).take
  end
end

shared_examples_for 'P&R Daily Update MFCM Daily Scenario 2: Updated measure with later start date outcome' do
  before { ChiefTransformer.instance.invoke }

  it 'creates no new measures' do
    expect(Measure.count).to eq 6
  end

  it 'moves measure validity_start_date forward for the existing measure' do
    expect(Measure.where(goods_nomenclature_item_id: '1210100010').count).to eq 1
  end
end

shared_examples_for 'P&R Daily Update MFCM Daily Scenario 3: Restriction applied to wrong commodity removed outcome' do
  before { ChiefTransformer.instance.invoke }

  it 'creates no new measures' do
    expect(Measure.count).to eq 6
  end

  it 'ends the measures with the current date' do
    m = Measure.where(goods_nomenclature_item_id: '1211300000',
                      validity_start_date: DateTime.parse('2006-07-24 08:45:00'),
                      validity_end_date: DateTime.parse('2006-07-24 08:45:00')).take
  end
end

shared_examples_for 'P&R Daily Update TAME and TAMF Daily Scenario 4: Country removed from restriction outcome' do
  before { ChiefTransformer.instance.invoke }

  it 'creates two new measures' do
    expect(Measure.count).to eq 5
    m1 = Measure.where(goods_nomenclature_item_id: '2106909829',
                       geographical_area_id: 'CN',
                       validity_start_date: DateTime.parse('2008-06-01 00:00:00')).take
    expect(m1.measure_conditions.count).to eq 2
    expect(m1.footnote_association_measures.count).to eq 1
    m2 = Measure.where(goods_nomenclature_item_id: '2106909829',
                       geographical_area_id: 'IQ',
                       validity_start_date: DateTime.parse('2008-06-01 00:00:00')).take
    expect(m2.measure_conditions.count).to eq 2
    expect(m2.footnote_association_measures.count).to eq 1
  end

  it 'ends the three old measures' do
    Measure.where(goods_nomenclature_item_id: '2106909829',
                  geographical_area_id: 'CN',
                  validity_start_date: DateTime.parse('2008-05-01 00:00:00'),
                  validity_end_date: DateTime.parse('2008-06-01 00:00:00')).take
    Measure.where(goods_nomenclature_item_id: '2106909829',
                  geographical_area_id: 'US',
                  validity_start_date: DateTime.parse('2008-05-01 00:00:00'),
                  validity_end_date: DateTime.parse('2008-06-01 00:00:00')).take
    Measure.where(goods_nomenclature_item_id: '2106909829',
                  geographical_area_id: 'IQ',
                  validity_start_date: DateTime.parse('2008-05-01 00:00:00'),
                  validity_end_date: DateTime.parse('2008-06-01 00:00:00')).take
  end
end
