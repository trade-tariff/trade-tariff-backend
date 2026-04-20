RSpec.describe TariffSynchronizer::FileService do
  let(:base_update) { create :base_update }

  context 'when development' do
    describe '.write_file' do
      it 'Saves the file in the local filesystem', :aggregate_failures do
        prepare_synchronizer_folders
        file_path = File.join(TariffSynchronizer.root_path, 'taric', 'hello.txt')

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

    describe 'S3 retry behaviour' do
      let(:transient_error) { Aws::S3::Errors::ServiceUnavailable.new(nil, 'Service Unavailable') }
      let(:non_transient_error) { Aws::S3::Errors::NoSuchKey.new(nil, 'Not Found') }
      let(:access_denied_error) { Aws::S3::Errors::AccessDenied.new(nil, 'Access Denied') }
      let(:network_error) { Seahorse::Client::NetworkingError.new(RuntimeError.new('connection timeout')) }

      before do
        # Prevent real sleeps during retries
        allow(described_class).to receive(:s3_backoff)
      end

      context 'when a transient error occurs then succeeds' do
        let(:aws_object_output) { instance_double(Aws::S3::Types::GetObjectOutput, body: 'content') }

        before do
          call_count = 0
          allow(aws_object).to receive(:get) do
            call_count += 1
            raise transient_error if call_count == 1

            aws_object_output
          end
        end

        it 'retries and returns the result' do
          result = described_class.get('data/some-file.txt')

          expect(aws_object).to have_received(:get).twice
          expect(result).to eq('content')
        end

        it 'logs a warning for the failed attempt' do
          allow(Rails.logger).to receive(:warn)

          described_class.get('data/some-file.txt')

          expect(Rails.logger).to have_received(:warn).with(/FileService get attempt 1 failed/)
        end
      end

      context 'when a transient error persists beyond S3_MAX_RETRIES' do
        before do
          allow(aws_object).to receive(:get).and_raise(transient_error)
        end

        it 'retries S3_MAX_RETRIES times then raises' do
          expect { described_class.get('data/some-file.txt') }
            .to raise_error(Aws::S3::Errors::ServiceUnavailable)

          expect(aws_object).to have_received(:get).exactly(described_class::S3_MAX_RETRIES + 1).times
        end

        it 'applies backoff between each retry' do
          expect { described_class.get('data/some-file.txt') }.to raise_error(Aws::S3::Errors::ServiceUnavailable)

          expect(described_class).to have_received(:s3_backoff).exactly(described_class::S3_MAX_RETRIES).times
        end

        it 'logs an error after retries are exhausted' do
          allow(Rails.logger).to receive(:error)

          expect { described_class.get('data/some-file.txt') }.to raise_error(Aws::S3::Errors::ServiceUnavailable)

          expect(Rails.logger).to have_received(:error).with(/FileService get failed for 'data\/some-file.txt' after #{described_class::S3_MAX_RETRIES} retries/)
        end
      end

      context 'when a non-transient error (NoSuchKey) occurs' do
        before do
          allow(aws_object).to receive(:get).and_raise(non_transient_error)
        end

        it 'raises immediately without any retry' do
          expect { described_class.get('data/some-file.txt') }
            .to raise_error(Aws::S3::Errors::NoSuchKey)

          expect(aws_object).to have_received(:get).once
        end

        it 'does not apply backoff' do
          expect { described_class.get('data/some-file.txt') }.to raise_error(Aws::S3::Errors::NoSuchKey)

          expect(described_class).not_to have_received(:s3_backoff)
        end

        it 'logs an error immediately' do
          allow(Rails.logger).to receive(:error)

          expect { described_class.get('data/some-file.txt') }.to raise_error(Aws::S3::Errors::NoSuchKey)

          expect(Rails.logger).to have_received(:error).with(/non-transient/)
        end
      end

      context 'when a non-transient error (AccessDenied) occurs' do
        before do
          allow(aws_object).to receive(:get).and_raise(access_denied_error)
        end

        it 'raises immediately without any retry' do
          expect { described_class.get('data/some-file.txt') }
            .to raise_error(Aws::S3::Errors::AccessDenied)

          expect(aws_object).to have_received(:get).once
        end
      end

      context 'when a network error occurs' do
        before do
          allow(aws_object).to receive(:get).and_raise(network_error)
        end

        it 'treats it as transient and retries' do
          expect { described_class.get('data/some-file.txt') }
            .to raise_error(Seahorse::Client::NetworkingError)

          expect(aws_object).to have_received(:get).exactly(described_class::S3_MAX_RETRIES + 1).times
        end
      end

      context 'when write_file encounters a transient error' do
        before do
          allow(aws_object).to receive(:put).and_raise(transient_error)
        end

        it 'retries S3_MAX_RETRIES times then raises' do
          expect { described_class.write_file('data/some-file.txt', 'Hello World') }
            .to raise_error(Aws::S3::Errors::ServiceUnavailable)

          expect(aws_object).to have_received(:put).exactly(described_class::S3_MAX_RETRIES + 1).times
        end
      end
    end
  end
end
