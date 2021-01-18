shared_examples_for 'VAT and Excise TAME Daily Scenario 1: Changed VAT rate outcome' do
  before { ChiefTransformer.instance.invoke }

  it 'creates two new measures' do
    expect(Measure.count).to eq 5
  end

  it 'adds end date to measure 0101010100' do
    m = Measure.where(goods_nomenclature_item_id: '0101010100',
                      validity_start_date: DateTime.parse('2007-11-15 11:00:00'),
                      validity_end_date: DateTime.parse('2008-04-01 00:00:00')).take
    expect(m.measure_components.first.duty_amount).to eq 15
  end

  it 'adds end date to measure 0202020200' do
    m = Measure.where(goods_nomenclature_item_id: '0202020200',
                      validity_start_date: DateTime.parse('2008-01-01 00:00:00'),
                      validity_end_date: DateTime.parse('2008-04-01 00:00:00')).take
    expect(m.measure_components.first.duty_amount).to eq 15
  end

  it 'increases Duty Amount to 17% for measure 0303030300' do
    m = Measure.where(goods_nomenclature_item_id: '0303030300',
                      validity_start_date: DateTime.parse('2008-04-30 14:00:00')).take
    expect(m.measure_components.first.duty_amount).to eq 17
  end

  it 'creates new Measure for 0101010100 with duty amount of 17%' do
    m = Measure.where(goods_nomenclature_item_id: '0101010100',
                      validity_start_date: DateTime.parse('2008-04-01 00:00:00')).take
    expect(m.measure_components.first.duty_amount).to eq 17
  end

  it 'creates new Measure for 0202020200 with duty amount of 17%' do
    m = Measure.where(goods_nomenclature_item_id: '0202020200',
                      validity_start_date: DateTime.parse('2008-04-01 00:00:00')).take
    expect(m.measure_components.first.duty_amount).to eq 17
  end
end

shared_examples_for 'VAT and Excise TAME Daily Scenario 2: VAT applied to another commodity code outcome' do
  before { ChiefTransformer.instance.invoke }

  it 'adds validity end date to commodity 0101010100' do
    m = Measure.where(goods_nomenclature_item_id: '0101010100',
                      validity_start_date: DateTime.parse('2007-11-15 11:00:00'),
                      validity_end_date: DateTime.parse('2008-04-01 00:00:00')).take
    expect(m.measure_components.first.duty_amount).to eq 15
  end

  it 'creates commodity 0404040400' do
    m = Measure.where(goods_nomenclature_item_id: '0404040400',
                      validity_start_date: DateTime.parse('2008-04-01 00:00:00')).take
    expect(m.measure_components.first.duty_amount).to eq 15
  end
end

shared_examples_for 'VAT and Excise TAME Daily Scenario 3: VAT no longer applied to commodity outcome' do
  before { ChiefTransformer.instance.invoke }

  it 'adds validity end date to commodity 0101010100' do
    m = Measure.where(goods_nomenclature_item_id: '0101010100',
                      validity_start_date: DateTime.parse('2007-11-15 11:00:00'),
                      validity_end_date: DateTime.parse('2008-04-01 00:00:00')).take
    expect(m.measure_components.first.duty_amount).to eq 15
  end
end

shared_examples_for 'VAT and Excise TAME Daily Scenario 4: VAT applied to additional commodity outcome' do
  before { ChiefTransformer.instance.invoke }

  it 'creates new measure for commodity 0404040400' do
    m = Measure.where(goods_nomenclature_item_id: '0404040400',
                      validity_start_date: DateTime.parse('2008-01-01 00:00:00')).take
    expect(m.measure_components.first.duty_amount).to eq 15
  end
end

shared_examples_for 'VAT and Excise TAME Daily Scenario 5: VAT applied to incorrect commodity outcome' do
  before { ChiefTransformer.instance.invoke }

  it 'adds end date to commodity 0101010100' do
    m = Measure.where(goods_nomenclature_item_id: '0101010100',
                      validity_start_date: DateTime.parse('2007-11-15 11:00:00'),
                      validity_end_date: DateTime.parse('2007-11-15 11:00:00')).take
    expect(m.measure_components.first.duty_amount).to eq 15
  end
end

shared_examples_for 'VAT and Excise TAME Daily Scenario 6: VAT removed outcome' do
  before { ChiefTransformer.instance.invoke }

  it 'keeps three measures in the database' do
    expect(Measure.count).to eq 3
  end

  it 'adds validity end date to commodity 0101010100' do
    m = Measure.where(goods_nomenclature_item_id: '0101010100',
                      validity_start_date: DateTime.parse('2007-11-15 11:00:00'),
                      validity_end_date: DateTime.parse('2008-04-01 00:00:00')).take
    expect(m.measure_components.first.duty_amount).to eq 15
  end

  it 'adds validity end date to commodity 0202020100' do
    m = Measure.where(goods_nomenclature_item_id: '0202020200',
                      validity_start_date: DateTime.parse('2008-01-01 00:00:00'),
                      validity_end_date: DateTime.parse('2008-04-01 00:00:00')).take
    expect(m.measure_components.first.duty_amount).to eq 15
  end

  it 'adds validity end date to commodity 0303030300' do
    m = Measure.where(goods_nomenclature_item_id: '0303030300',
                      validity_start_date: DateTime.parse('2008-04-30 14:00:00'),
                      validity_end_date: DateTime.parse('2008-05-01 00:00:00')).take
    expect(m.measure_components.first.duty_amount).to eq 15
  end
end

shared_examples_for 'VAT and Excise TAME Daily Scenario 7: Incorrect VAT rate outcome' do
  before { ChiefTransformer.instance.invoke }

  it 'updates duty amount for commodity 0101010100 measure' do
    m = Measure.where(goods_nomenclature_item_id: '0101010100',
                      validity_start_date: DateTime.parse('2007-11-15 11:00:00')).take
    expect(m.measure_components.first.duty_amount).to eq 17.0
  end

  it 'updates duty amount for commodity 0202020200 measure' do
    m = Measure.where(goods_nomenclature_item_id: '0202020200',
                      validity_start_date: DateTime.parse('2008-01-01 00:00:00')).take
    expect(m.measure_components.first.duty_amount).to eq 17.0
  end

  it 'updates duty amount for commodity 0303030300 measure' do
    m = Measure.where(goods_nomenclature_item_id: '0303030300',
                      validity_start_date: DateTime.parse('2008-04-30 14:00:00')).take
    expect(m.measure_components.first.duty_amount).to eq 17.0
  end
end

shared_examples_for 'VAT and Excise TAMF Daily Scenario 1: Added max amount outcome' do
  before { ChiefTransformer.instance.invoke }

  it 'adds two new measures' do
    expect(Measure.count).to eq 8
  end

  it 'adds end date to measure for 0101010100' do
    m = Measure.where(goods_nomenclature_item_id: '0101010100',
                      validity_start_date: DateTime.parse('2007-11-15 11:00:00'),
                      validity_end_date: DateTime.parse('2008-04-01 00:00:00')).take
    expect(m.measure_components.first.duty_amount).to eq 10
  end

  it 'adds end date to measure for 0202020200' do
    m = Measure.where(goods_nomenclature_item_id: '0202020200',
                      validity_start_date: DateTime.parse('2008-01-01 00:00:00'),
                      validity_end_date: DateTime.parse('2008-04-01 00:00:00')).take
    expect(m.measure_components.first.duty_amount).to eq 10
  end

  it 'adds additional measure component to 0303030300' do
    m = Measure.where(goods_nomenclature_item_id: '0303030300',
                      validity_start_date: DateTime.parse('2008-04-30 14:00:00'),
                      measure_type_id: 'EGJ').take
    expect(m.measure_components.first.duty_amount).to eq 10
    expect(m.measure_components.last.duty_amount).to eq 2
  end

  it 'creates new measure  for 0101010100 with measure components for duty amount 10% and 2kg' do
    m = Measure.where(goods_nomenclature_item_id: '0101010100',
                      validity_start_date: DateTime.parse('2008-04-01 00:00:00'),
                      measure_type_id: 'EGJ').take
    expect(m.measure_components.first.duty_amount).to eq 10
    expect(m.measure_components.last.duty_amount).to eq 2
  end

  it 'creates new measure  for 0202020200 with measure components for duty amount 10% and 2kg' do
    m = Measure.where(goods_nomenclature_item_id: '0202020200',
                      validity_start_date: DateTime.parse('2008-04-01 00:00:00'),
                      measure_type_id: 'EGJ').take
    expect(m.measure_components.first.duty_amount).to eq 10
    expect(m.measure_components.last.duty_amount).to eq 2
  end
end

shared_examples_for 'VAT and Excise TAMF Daily Scenario 2: Missing max amount outcome' do
  before { ChiefTransformer.instance.invoke }

  it 'does not add new measures' do
    expect(Measure.count).to eq 6
  end

  it 'adds additional duty amount of 2kg to 0101010100' do
    m = Measure.where(goods_nomenclature_item_id: '0101010100',
                      validity_start_date: DateTime.parse('2007-11-15 11:00:00'),
                      measure_type_id: 'EGJ').take
    expect(m.measure_components.first.duty_amount).to eq 10
    expect(m.measure_components.last.duty_amount).to eq 2
  end

  it 'adds additional duty amount of 2kg to 0202020200' do
    m = Measure.where(goods_nomenclature_item_id: '0202020200',
                      validity_start_date: DateTime.parse('2008-01-01 00:00:00'),
                      measure_type_id: 'EGJ').take
    expect(m.measure_components.first.duty_amount).to eq 10
    expect(m.measure_components.last.duty_amount).to eq 2
  end

  it 'adds additional duty amount of 2kg to 0303030300' do
    m = Measure.where(goods_nomenclature_item_id: '0303030300',
                      validity_start_date: DateTime.parse('2008-04-30 14:00:00'),
                      measure_type_id: 'EGJ').take
    expect(m.measure_components.first.duty_amount).to eq 10
    expect(m.measure_components.last.duty_amount).to eq 2
  end
end

shared_examples_for 'VAT and Excise TAMF Daily Scenario 3: Removed max amount outcome' do
  before { ChiefTransformer.instance.invoke }

  it 'creates two new measures' do
    expect(Measure.count).to eq 8
  end

  it 'adds validity end date to 0101010100 measure' do
    m = Measure.where(goods_nomenclature_item_id: '0101010100',
                      validity_start_date: DateTime.parse('2007-11-15 11:00:00'),
                      validity_end_date: DateTime.parse('2008-04-01 00:00:00'),
                      measure_type_id: 'DAA').take
    expect(m.measure_components.first.duty_amount).to eq 20
    expect(m.measure_components.last.duty_amount).to eq 1
  end

  it 'adds validity end date to 0202020200 measure' do
    m = Measure.where(goods_nomenclature_item_id: '0202020200',
                      validity_start_date: DateTime.parse('2008-01-01 00:00:00'),
                      validity_end_date: DateTime.parse('2008-04-01 00:00:00'),
                      measure_type_id: 'DAA').take
    expect(m.measure_components.first.duty_amount).to eq 20
    expect(m.measure_components.last.duty_amount).to eq 1
  end

  it 'removes measure component (1kg) from 0303030300' do
    m = Measure.where(goods_nomenclature_item_id: '0303030300',
                      validity_start_date: DateTime.parse('2008-04-30 14:00:00'),
                      measure_type_id: 'DAA').take
    expect(m.measure_components.first.duty_amount).to eq 20
    expect(m.measure_components.size).to eq 1
  end

  it 'creates new measure for 0101010100 with duty amount of 20%' do
    m = Measure.where(goods_nomenclature_item_id: '0101010100',
                      validity_start_date: DateTime.parse('2008-04-01 00:00:00'),
                      measure_type_id: 'DAA').take
    expect(m.measure_components.first.duty_amount).to eq 20
  end

  it 'creates new measure for 0202020200 with duty amount of 20%' do
    m = Measure.where(goods_nomenclature_item_id: '0202020200',
                      validity_start_date: DateTime.parse('2008-04-01 00:00:00'),
                      measure_type_id: 'DAA').take
    expect(m.measure_components.first.duty_amount).to eq 20
  end
end

shared_examples_for 'VAT and Excise MFCM Daily Scenario 1: Updated measure with later start date outcome' do
  before { ChiefTransformer.instance.invoke }

  it 'no changes should be done to Measure because just fe_tsmp was moved forward' do
    m = Measure.where(goods_nomenclature_item_id: '0101010100',
                      validity_start_date: DateTime.parse('2007-11-15 11:00:00')).take
    expect(m.measure_components.first.duty_amount).to eq 15
  end
end

shared_examples_for 'VAT and Excise MFCM Daily Scenario 2: Updated measure with later start date outcome' do
  before { ChiefTransformer.instance.invoke }

  it 'leaves two measures in the table' do
    expect(Measure.count).to eq 2
  end

  it 'adds end date to existing measure' do
    m = Measure.where(goods_nomenclature_item_id: '0101010100',
                      validity_start_date: DateTime.parse('2007-11-15 11:00:00'),
                      validity_end_date: DateTime.parse('2007-12-31 11:00:00')).take
    expect(m.measure_components.first.duty_amount).to eq 15
  end

  it 'creates new measure with new start date' do
    m = Measure.where(goods_nomenclature_item_id: '0101010100',
                      validity_start_date: DateTime.parse('2008-01-01 00:00:00')).take
    expect(m.measure_components.first.duty_amount).to eq 15
  end
end

shared_examples_for 'VAT and Excise MFCM Daily Scenario 3: Updated measure with later start date for terminated measure outcome' do
  before { ChiefTransformer.instance.invoke }

  it 'adds end date to existing measure' do
    m1 = Measure.where(goods_nomenclature_item_id: '0101010100',
                       validity_start_date: DateTime.parse('2007-11-15 11:00:00'),
                       validity_end_date: DateTime.parse('2007-11-30 00:00:00')).take
    expect(m1.measure_components.first.duty_amount).to eq 15
  end

  it 'creates new measure with new start date' do
    m2 = Measure.where(goods_nomenclature_item_id: '0101010100',
                       validity_start_date: DateTime.parse('2008-01-01 00:00:00')).take
    expect(m2.measure_components.first.duty_amount).to eq 15
  end
end

shared_examples_for 'VAT and Excise MFCM Daily Scenario 4: Start date for measure moved forward outcome' do
  before { ChiefTransformer.instance.invoke }

  it 'deletes existing Matching measures' do
    Measure.where(goods_nomenclature_item_id: '0101010100',
                  validity_start_date: DateTime.parse('2007-11-15 11:00:00'),
                  validity_end_date: DateTime.parse('2007-11-15 11:00:00')).take
  end

  it 'inserts new measures' do
    m = Measure.where(goods_nomenclature_item_id: '0101010100',
                      validity_start_date: DateTime.parse('2008-01-01 00:00:00')).take
    expect(m.measure_components.first.duty_amount).to eq 15
  end
end

shared_examples_for 'Unsupported Scenario 1: Several updates in same daily update file outcome' do
  before { ChiefTransformer.instance.invoke }

  it 'creates two new measures' do
    expect(Measure.count).to eq 3
  end

  it 'adds end date to 0101010100 with duty amount of 20%' do
    m = Measure.where(goods_nomenclature_item_id: '0101010100',
                      validity_start_date: DateTime.parse('2008-01-01 00:00:00'),
                      validity_end_date: DateTime.parse('2008-02-01 00:00:00')).take
    expect(m.measure_components.first.duty_amount).to eq 20
  end

  it 'creates new temporary measure for 0101010100 with duty amount of 20%' do
    m = Measure.where(goods_nomenclature_item_id: '0101010100',
                      validity_start_date: DateTime.parse('2008-02-01 00:00:00'),
                      validity_end_date: DateTime.parse('2008-04-01 00:00:00')).take
    expect(m.measure_components.first.duty_amount).to eq 19
  end

  it 'creates new measure for 0101010100 with duty amount of 18' do
    m = Measure.where(goods_nomenclature_item_id: '0101010100',
                      validity_start_date: DateTime.parse('2008-04-01 00:00:00')).take
    expect(m.measure_components.first.duty_amount).to eq 18
  end
end

shared_examples_for 'Unsupported Scenario 2: Insert and delete in same daily update file outcome' do
  before { ChiefTransformer.instance.invoke }

  it 'no Taric measures should be created' do
    expect(Measure.count).to eq 0
  end
end

shared_examples_for 'Unsupported Scenario 3: Insert and update in same daily file outcome' do
  before { ChiefTransformer.instance.invoke }

  it 'creates measure for 0101010100 with duty rate of 15%' do
    expect(Measure.count).to eq 1
    m = Measure.where({ validity_start_date: DateTime.parse('2008-03-01 00:00:00'),
                        goods_nomenclature_item_id: '0101010100' }).take
    expect(m.measure_components.first.duty_amount).to eq 15
  end
end
