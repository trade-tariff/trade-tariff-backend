require 'timeout'

module ImageDescriptions
  # Development-only Linux/Nix decoder. No credentials, home directory or network
  # are visible to the native image parsers. Production needs its own worker image.
  class Normalise
    InvalidImage = Class.new(StandardError)
    Unavailable = Class.new(StandardError)
    MAX_PIXELS = 50_000_000
    MAX_DIMENSION = 16_384
    MAX_OUTPUT_BYTES = 3_000_000
    MAX_COMMAND_OUTPUT = 131_072
    COMMAND_TIMEOUT = 8

    def self.call(job) = new(job).call

    def initialize(job)
      @directory = job.directory
    end

    def call
      header = command('vipsheader', '-a', '/work/input')
      width = field(header, 'width')
      height = field(header, 'height')
      pages = field(header, 'n-pages') || 1
      unless width&.positive? && height&.positive? && width <= MAX_DIMENSION && height <= MAX_DIMENSION && width * height <= MAX_PIXELS
        raise InvalidImage, 'Choose an image with no more than 50 megapixels and 16,384 pixels on either side.'
      end
      raise InvalidImage, 'Choose a still image with one page or frame.' unless pages == 1

      command('vips', 'thumbnail', '/work/input', '/work/normalised.jpg[Q=85,strip]', '2048', '--height', '2048', '--size', 'down', '--fail-on', 'warning', '--output-profile', 'srgb')
      output = @directory.join('normalised.jpg')
      raise InvalidImage, 'Choose a smaller or simpler image.' unless output.file? && output.size.positive? && output.size <= MAX_OUTPUT_BYTES

      output
    end

  private

    def field(header, name)
      header[/^#{Regexp.escape(name)}: (\d+)\s*$/, 1]&.to_i
    end

    def executable(name)
      ENV.fetch('PATH').split(File::PATH_SEPARATOR).map { |path| File.join(path, name) }.find { |path| File.executable?(path) && !File.directory?(path) } ||
        raise(Unavailable, 'Image conversion tools are not available.')
    end

    def command(program, *arguments)
      output_path = @directory.join('command-output')
      sandbox = [
        executable('bwrap'),
        '--unshare-all',
        '--die-with-parent',
        '--new-session',
        '--ro-bind',
        '/nix/store',
        '/nix/store',
        '--bind',
        @directory.to_s,
        '/work',
        '--proc',
        '/proc',
        '--dev',
        '/dev',
        '--tmpfs',
        '/tmp',
        '--chdir',
        '/work',
        '--',
        executable(program),
        *arguments,
      ]
      environment = { 'PATH' => ENV.fetch('PATH'), 'HOME' => '/tmp', 'VIPS_CONCURRENCY' => '1', 'VIPS_BLOCK_UNTRUSTED' => '1' }
      File.open(output_path, 'wb', 0o600) do |output|
        pid = Process.spawn(environment, *sandbox,
                            unsetenv_others: true, pgroup: true, out: output, err: output,
                            rlimit_cpu: 8, rlimit_as: 1.gigabyte, rlimit_fsize: 4.megabytes, rlimit_nofile: 128)
        begin
          _, status = Timeout.timeout(COMMAND_TIMEOUT) { Process.wait2(pid) }
          raise InvalidImage, 'This image could not be read. Choose a different image.' unless status.success?
        rescue Timeout::Error
          Process.kill('KILL', -pid)
          Process.wait(pid)
          raise InvalidImage, 'This image took too long to read. Choose a smaller image.'
        end
      end
      result = File.binread(output_path, MAX_COMMAND_OUTPUT + 1).to_s
      raise InvalidImage, 'This image contains too much metadata. Choose a different image.' if result.bytesize > MAX_COMMAND_OUTPUT

      result
    ensure
      File.delete(output_path) if output_path&.file?
    end
  end
end
