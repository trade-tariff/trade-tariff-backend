describe TariffSynchronizer::FileService do
  let(:base_update) { create :base_update }

  context 'in development' do
    describe '.write_file' do
      it 'Saves the file in the local filesystem' do
        FakeFS do
          prepare_synchronizer_folders
          file_path = File.join(TariffSynchronizer.root_path, 'chief', 'hello.txt')

          described_class.write_file(file_path, 'Hello World')

          expect(File.exist?(file_path)).to be true
          expect(File.read(file_path)).to eq('Hello World')
        end
      end
    end

    describe '.file_exists?' do
      it 'checks the file in the local filesystem' do
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
      it 'returns a IO object with the associated file info' do
        allow(base_update).to receive(:file_path).and_return('spec/fixtures/hello_world.txt')
        result = described_class.file_as_stringio(base_update)
        expect(result).to be_kind_of(IO)
        expect(result.read).to eq("hola mundo\n")
      end
    end
  end

  context 'in production' do
    before do
      string_inquirer = ActiveSupport::StringInquirer.new('production')
      allow(Rails).to receive(:env).and_return(string_inquirer)

      aws_resource = instance_double('Aws::S3::Resource')
      @aws_bucket = instance_double('Aws::S3::Bucket')
      @aws_object = instance_double('Aws::S3::Object')
      expect(Aws::S3::Resource).to receive(:new).and_return(aws_resource)
      expect(aws_resource).to receive(:bucket).with('trade-tariff-backend').and_return(@aws_bucket)
    end

    describe '.write_file' do
      it 'Saves the file to a S3 bucket in if is the production environment' do
        expect(@aws_bucket).to receive(:object).with('data/some-file.txt').and_return(@aws_object)
        expect(@aws_object).to receive(:put).with(body: 'Hello World')

        described_class.write_file('data/some-file.txt', 'Hello World')
      end
    end

    describe '.file_exists?' do
      it 'Saves the file to a S3 bucket in if is the production environment' do
        expect(@aws_bucket).to receive(:object).with('data/some-file.txt').and_return(@aws_object)
        expect(@aws_object).to receive(:exists?)

        described_class.file_exists?('data/some-file.txt')
      end
    end

    describe '.file_size' do
      it 'returns the file size in the local filesystem' do
        expect(@aws_bucket).to receive(:object).with('data/some-file.txt').and_return(@aws_object)
        expect(@aws_object).to receive(:size)

        described_class.file_size('data/some-file.txt')
      end
    end

    describe '.file_as_stringio' do
      it 'calls amazon s3 to get the object with the same file_path and returns a string io' do
        allow(base_update).to receive(:file_path).and_return('data/some-file.txt')
        aws_object_output = instance_double('Aws::S3::Types::GetObjectOutput')
        expect(@aws_bucket).to receive(:object).with('data/some-file.txt').and_return(@aws_object)
        expect(@aws_object).to receive(:get).and_return(aws_object_output)
        expect(aws_object_output).to receive(:body)

        described_class.file_as_stringio(base_update)
      end
    end
  end
end
