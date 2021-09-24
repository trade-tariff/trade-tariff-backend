RSpec.describe RingBuffer do
  describe '#push' do
    let(:ring_buffer) { described_class.new(2) }

    context 'with element limit not reached' do
      before do
        ring_buffer.push('foo')
        ring_buffer.push('bar')
      end

      it 'pushes and keeps all elements' do
        expect(ring_buffer.to_a).to eq %w[foo bar]
      end
    end

    context 'with element limit reached' do
      before do
        ring_buffer.push('foo')
        ring_buffer.push('bar')
        ring_buffer.push('baz')
      end

      it 'pushes new element, popping out the first one (FIFO)' do
        expect(ring_buffer.to_a).to eq %w[bar baz]
      end
    end
  end

  describe '#full?' do
    let(:ring_buffer) { described_class.new(1) }

    context 'element limit reached' do
      before { ring_buffer.push('foo') }

      it 'returns true' do
        expect(ring_buffer).to be_full
      end
    end

    context 'element limit not reached' do
      it 'returns false' do
        expect(ring_buffer).not_to be_full
      end
    end
  end
end
