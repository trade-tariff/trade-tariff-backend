RSpec.describe TariffSynchronizer::FileService do
  let(:base_update) { create :base_update }

  context 'when development' do
    describe '.write_file' do
      it 'Saves the file in the local filesystem', :aggregate_failures do
        prepare_synchronizer_folders
        file_path = File.join(TariffSynchronizer.root_path, 'chief', 'hello.txt')

        described_class.write_file(file_path, 'Hello World')

        expect(File.exist?(file_path)).to be true
        expect(File.read(file_path)).to eq('Hello World')
      end
    end

    describe '.file_exists?' do
      it 'checks the file in the local filesystem', :aggregate_failures do
        result = described_class.file_exists?('spec/fixtures/hello_world.txt')
        expect(result).to be true

        result = described_class.file_exists?('spec/fixtures/hola_mundo.txt')
        expect(result).to be false
      end
    end

    describe '.file_size' do
      it 'returns the file size in the local filesystem' do
        result = described_class.file_size('spec/fixtures/hello_world.txt')
        expect(result).to be 11
      end
    end

    describe '.file_as_stringio' do
      it 'returns a IO object with the associated file info', :aggregate_failures do
        allow(base_update).to receive(:file_path).and_return('spec/fixtures/hello_world.txt')
        result = described_class.file_as_stringio(base_update)
        expect(result).to be_a(IO)
        expect(result.read).to eq("hola mundo\n")
      end
    end
  end

  context 'when production' do
    let(:aws_resource) { instance_double(Aws::S3::Resource) }
    let(:aws_bucket) { instance_double(Aws::S3::Bucket) }
    let(:aws_object) { instance_double(Aws::S3::Object) }

    before do
      string_inquirer = ActiveSupport::StringInquirer.new('production')

      allow(Rails).to receive(:env).and_return(string_inquirer)
      allow(Aws::S3::Resource).to receive(:new).and_return(aws_resource)
      allow(aws_bucket).to receive(:object).with('data/some-file.txt').and_return(aws_object)
      allow(aws_object).to receive(:put).with(body: 'Hello World')
      allow(aws_resource).to receive(:bucket).with('trade-tariff-backend').and_return(aws_bucket)
    end

    describe '.write_file' do
      it 'Saves the file to a S3 bucket in if is the production environment', :aggregate_failures do
        described_class.write_file('data/some-file.txt', 'Hello World')

        expect(aws_bucket).to have_received(:object).with('data/some-file.txt')
        expect(aws_object).to have_received(:put).with(body: 'Hello World')
      end
    end

    describe '.file_exists?' do
      it 'Saves the file to a S3 bucket in if is the production environment', :aggregate_failures do
        allow(aws_object).to receive(:exists?).and_return(true)
        described_class.file_exists?('data/some-file.txt')

        expect(aws_bucket).to have_received(:object).with('data/some-file.txt')
        expect(aws_object).to have_received(:exists?)
      end
    end

    describe '.file_size' do
      it 'returns the file size in the local filesystem', :aggregate_failures do
        allow(aws_object).to receive(:size).and_return(1)
        described_class.file_size('data/some-file.txt')

        expect(aws_bucket).to have_received(:object).with('data/some-file.txt')
        expect(aws_object).to have_received(:size)
      end
    end

    describe '.file_as_stringio' do
      it 'calls amazon s3 to get the object with the same file_path and returns a string io', :aggregate_failures do
        aws_object_output = instance_double(Aws::S3::Types::GetObjectOutput)

        allow(base_update).to receive(:file_path).and_return('data/some-file.txt')
        allow(aws_object).to receive(:get).and_return(aws_object_output)
        allow(aws_object_output).to receive(:body)

        described_class.file_as_stringio(base_update)
        expect(aws_bucket).to have_received(:object).with('data/some-file.txt')
        expect(aws_object).to have_received(:get)
        expect(aws_object_output).to have_received(:body)
      end
    end
  end
end
