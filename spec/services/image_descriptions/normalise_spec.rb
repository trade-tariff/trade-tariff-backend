RSpec.describe ImageDescriptions::Normalise do
  let(:directory) { Pathname(Dir.mktmpdir('normalise-image-spec')) }
  let(:job) { instance_double(ImageDescription, directory:) }
  let(:header) { "width: 100\nheight: 100\nn-pages: 1\n" }
  let(:status) { instance_double(Process::Status, success?: true) }

  before do
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with('PATH').and_return('/tools')
    allow(File).to receive(:executable?).and_call_original
    %w[bwrap vipsheader vips].each { |name| allow(File).to receive(:executable?).with("/tools/#{name}").and_return(true) }
    allow(Process).to receive(:spawn) do |_env, *args, **options|
      if args.include?('/tools/vipsheader')
        options[:out].write(header)
      else
        File.binwrite(directory.join('normalised.jpg'), 'normalised-bytes')
      end
      1234
    end
    allow(Process).to receive(:wait2).with(1234).and_return([1234, status])
  end

  after { FileUtils.remove_entry(directory) }

  it 'accepts silent converter success' do
    expect(described_class.call(job)).to eq(directory.join('normalised.jpg'))
    expect(Process).to have_received(:spawn).with(
      { 'PATH' => '/tools', 'HOME' => '/tmp', 'VIPS_CONCURRENCY' => '1', 'VIPS_BLOCK_UNTRUSTED' => '1' },
      '/tools/bwrap', '--unshare-all', '--die-with-parent', '--new-session',
      '--ro-bind', '/nix/store', '/nix/store', '--bind', directory.to_s, '/work',
      '--proc', '/proc', '--dev', '/dev', '--tmpfs', '/tmp', '--chdir', '/work', '--', '/tools/vipsheader', '-a', '/work/input',
      hash_including(unsetenv_others: true, rlimit_cpu: 8, rlimit_as: 1.gigabyte, rlimit_fsize: 4.megabytes)
    )
  end

  context 'with too many pixels' do
    let(:header) { "width: 10000\nheight: 10000\n" }

    it 'rejects before raster conversion' do
      expect { described_class.call(job) }.to raise_error(described_class::InvalidImage, /50 megapixels/)
      expect(Process).to have_received(:spawn).once
    end
  end

  context 'with multiple frames' do
    let(:header) { "width: 100\nheight: 100\nn-pages: 2\n" }

    it 'rejects rather than dropping frames' do
      expect { described_class.call(job) }.to raise_error(described_class::InvalidImage, /one page or frame/)
      expect(Process).to have_received(:spawn).once
    end
  end

  it 'kills an over-budget decoder group' do
    allow(Timeout).to receive(:timeout).and_raise(Timeout::Error)
    allow(Process).to receive(:kill)
    allow(Process).to receive(:wait).with(1234)

    expect { described_class.call(job) }.to raise_error(described_class::InvalidImage, /too long/)
    expect(Process).to have_received(:kill).with('KILL', -1234)
  end
end
