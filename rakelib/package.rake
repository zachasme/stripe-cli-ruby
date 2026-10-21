#
#  Rake tasks to build one gem per platform, each with the matching binary from stripe/stripe-cli.
#
#  - rake gem:ruby           # Build the ruby gem (no binary)
#  - rake gem:<platform>     # Build the gem for one platform in StripeCLI::Upstream::NATIVE_PLATFORMS
#  - rake package            # Build all of them into pkg/
#  - rake download           # Download and verify all binaries into exe/<platform>/stripe
#
#  The native gems put the binary at exe/<platform>/stripe. The ruby script exe/stripe finds it
#  and execs it, because rubygems requires a gem's executables to be Ruby scripts.
#
require "rubygems/package_task"
require "open-uri"
require "zlib"
require_relative "../lib/stripe_cli/upstream"

def stripe_cli_download_url(filename)
  "https://github.com/stripe/stripe-cli/releases/download/v#{StripeCLI::Upstream::VERSION}/#{filename}"
end

STRIPECLI_GEMSPEC = Bundler.load_gemspec("stripe-cli-ruby.gemspec")

# prepend the download task before the Gem::PackageTask tasks
task package: :download

gem_path = Gem::PackageTask.new(STRIPECLI_GEMSPEC).define
desc "Build the ruby gem"
task "gem:ruby" => [ gem_path ]

tmpdir = "tmp"
directory tmpdir

sumpath = File.join(tmpdir, "stripe_#{StripeCLI::Upstream::VERSION}_checksums.txt")
file sumpath => [ tmpdir ] do
  %w[ linux mac ].each do |platform|
    checksums_url = stripe_cli_download_url("stripe-#{platform}-checksums.txt")
    warn "Downloading checksums from #{checksums_url} ..."

    File.open(sumpath, "a") do |local|
      URI.open(checksums_url) do |remote|
        local.write(remote.read)
      end
    end
  end
end

tarpaths = []
exepaths = []
StripeCLI::Upstream::NATIVE_PLATFORMS.each do |platform, filename|
  STRIPECLI_GEMSPEC.dup.tap do |gemspec|
    tarpath = File.join(tmpdir, filename)
    tarpaths << tarpath

    exedir = File.join(gemspec.bindir, platform) # "exe/x86_64-linux"
    exepath = File.join(exedir, "stripe") # "exe/x86_64-linux/stripe"
    exepaths << exepath

    # modify a copy of the gemspec to include the native executable
    gemspec.platform = platform
    gemspec.files += [ exepath, "LICENSE-DEPENDENCIES" ]

    # create a package task
    gem_path = Gem::PackageTask.new(gemspec).define
    desc "Build the #{platform} gem"
    task "gem:#{platform}" => [ gem_path ]

    file tarpath => [ tmpdir ] do
      release_url = stripe_cli_download_url(filename)
      warn "Downloading #{tarpath} from #{release_url} ..."

      URI.open(release_url) do |remote|
        File.open(tarpath, "wb") do |local|
          local.write(remote.read)
        end
      end
    end

    directory exedir
    file exepath => [ tarpath, sumpath, exedir ] do
      checksums = File.open(sumpath).each_line.map do |line|
        checksum, file = line.split
        [ File.basename(file), checksum ]
      end.to_h

      local_sha256 = Digest::SHA256.file(tarpath).hexdigest
      remote_sha256 = checksums.fetch(filename)

      if local_sha256 == remote_sha256
        puts "Checksum OK for #{exepath} (#{local_sha256})"
      else
        abort "Checksum mismatch for #{exepath} (#{local_sha256} != #{remote_sha256})"
      end

      warn "Extracting #{tarpath} ..."

      File.open(tarpath) do |tarball|
        Zlib::GzipReader.wrap(tarball) do |gz|
          Gem::Package::TarReader.new(gz) do |reader|
            reader.seek("stripe") do |file|
              File.binwrite(exepath, file.read)
            end
          end
        end
      end
      FileUtils.chmod(0755, exepath, verbose: true)
    end
  end
end

desc "Download all stripe cli binaries"
task "download" => exepaths

CLOBBER.add(tmpdir)
CLOBBER.add(exepaths.map { |p| File.dirname(p) })
