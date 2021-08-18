
RSpec.describe LoopingSequence do
  it 'progresses from the first value to the last then loops back' do
    sequence = described_class.new('a'..'z')

    expect(sequence.value).to eq 'a'
    expect(sequence.next.value).to eq 'b'

    22.times { sequence.next }

    expect(sequence.next.value).to eq 'y'
    expect(sequence.next.value).to eq 'z'
    expect(sequence.next.value).to eq 'a'
  end

  it 'works with larger ranges' do
    sequence = described_class.new('aa'..'zz')

    expect(sequence.value).to eq 'aa'
    expect(sequence.next.value).to eq 'ab'

    672.times { sequence.next }

    expect(sequence.next.value).to eq 'zy'
    expect(sequence.next.value).to eq 'zz'
    expect(sequence.next.value).to eq 'aa'
  end

  it 'includes a preset a-Z, without punctuation' do
    sequence = described_class.lower_a_to_upper_z

    expect(sequence.value).to eq 'a'
    expect(sequence.next.value).to eq 'b'

    22.times { sequence.next }

    expect(sequence.next.value).to eq 'y'
    expect(sequence.next.value).to eq 'z'
    expect(sequence.next.value).to eq 'A'

    23.times { sequence.next }

    expect(sequence.next.value).to eq 'Y'
    expect(sequence.next.value).to eq 'Z'
    expect(sequence.next.value).to eq 'a'
  end
end
