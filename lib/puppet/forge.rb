require 'net/http'
require 'tempfile'
require 'uri'
require 'pathname'

$LOAD_PATH.push File.join(File.dirname(__FILE__), 'external/semantic')
require 'semantic/version'
require 'semantic/version_range'
require 'semantic/dependency'
require 'semantic/dependency/module_release'
require 'semantic/dependency/source'
require 'semantic/dependency/graph'
require 'semantic/dependency/unsatisfiable_graph'
$LOAD_PATH.pop

class Puppet::Forge < Semantic::Dependency::Source
  require 'puppet/forge/repository'
  require 'puppet/forge/errors'

  include Puppet::Forge::Errors

  USER_AGENT = "PMT/1.1.0 (v3; Net::HTTP)".freeze

  attr_reader :host, :repository

  def initialize(host = Puppet[:module_repository])
    @host = host
    @repository = Puppet::Forge::Repository.new(host, USER_AGENT)
  end

  # Return a list of module metadata hashes that match the search query.
  # This return value is used by the module_tool face install search,
  # and displayed to on the console.
  #
  # Example return value:
  #
  # [
  #   {
  #     "author"      => "puppetlabs",
  #     "name"        => "bacula",
  #     "tag_list"    => ["backup", "bacula"],
  #     "releases"    => [{"version"=>"0.0.1"}, {"version"=>"0.0.2"}],
  #     "full_name"   => "puppetlabs/bacula",
  #     "version"     => "0.0.2",
  #     "project_url" => "http://github.com/puppetlabs/puppetlabs-bacula",
  #     "desc"        => "bacula"
  #   }
  # ]
  #
  # @param term [String] search term
  # @return [Array] modules found
  # @raise [Puppet::Forge::Errors::CommunicationError] if there is a network
  #   related error
  # @raise [Puppet::Forge::Errors::SSLVerifyError] if there is a problem
  #   verifying the remote SSL certificate
  # @raise [Puppet::Forge::Errors::ResponseError] if the repository returns a
  #   bad HTTP response
  def search(term)
    matches = []
    uri = "/v3/modules?query=#{URI.escape(term)}"

    while uri
      response = make_http_request(uri)

      if response.code == '200'
        result = PSON.parse(response.body)
        uri = result['pagination']['next']
        matches.concat result['results']
      else
        raise ResponseError.new(:uri => uri , :input => term, :response => response)
      end
    end

    matches.each do |mod|
      mod['author'] = mod['owner']['username']
      mod['tag_list'] = mod['current_release']['tags']
      mod['full_name'] = "#{mod['author']}/#{mod['name']}"
      mod['version'] = mod['current_release']['version']
      mod['project_url'] = mod['homepage_url']
      mod['desc'] = mod['current_release']['metadata']['summary'] || ''
    end
  end

  def fetch(input)
    name = input.tr('/', '-')
    uri = "/v3/releases?module=#{name}"
    releases = []

    while uri
      response = make_http_request(uri)

      if response.code == '200'
        response = PSON.parse(response.body)
      else
        raise ResponseError.new(:uri => uri, :input => input, :response => response)
      end

      releases.concat(process(response['results']))
      uri = response['pagination']['next']
    end

    with_matched_requirements = releases.select do |x|
      Puppet::ModuleTool.has_pe_requirement?(x.metadata) &&
      Puppet::ModuleTool.meets_all_pe_requirements(x.metadata)
    end

    if with_matched_requirements.any?
      Puppet.debug "Found supported release for #{name}; excluding unsupported releases"
      return with_matched_requirements
    end

    return releases
  end

  def make_http_request(*args)
    @repository.make_http_request(*args)
  end

  class ModuleRelease < Semantic::Dependency::ModuleRelease
    attr_reader :install_dir, :metadata

    def initialize(source, data)
      @data = data
      @metadata = meta = data['metadata']

      name = meta['name'].tr('/', '-')
      version = Semantic::Version.parse(meta['version'])

      dependencies = (meta['dependencies'] || [])
      dependencies.map! do |dep|
        range = dep['version_requirement'] || dep['versionRequirement'] || '>=0'
        [
          dep['name'].tr('/', '-'),
          (Semantic::VersionRange.parse(range) rescue Semantic::VersionRange::EMPTY_RANGE),
        ]
      end

      super(source, name, version, Hash[dependencies])
    end

    def install(dir)
      staging_dir = self.prepare

      module_dir = dir + name[/-(.*)/, 1]
      module_dir.rmtree if module_dir.exist?

      FileUtils.mv(staging_dir, module_dir)
      @install_dir = dir

      # Return the Pathname object representing the directory where the
      # module release archive was unpacked the to.
      return module_dir
    ensure
      staging_dir.rmtree if staging_dir.exist?
    end

    def prepare
      return @unpacked_into if @unpacked_into

      download(@data['file_uri'], tmpfile)
      validate_checksum(tmpfile, @data['file_md5'])
      unpack(tmpfile, tmpdir)

      @unpacked_into = Pathname.new(tmpdir)
    end

    private

    # Obtain a suitable temporary path for unpacking tarballs
    #
    # @return [Pathname] path to temporary unpacking location
    def tmpdir
      @dir ||= Dir.mktmpdir(name, Puppet::Forge::Cache.base_path)
    end

    def tmpfile
      @file ||= Tempfile.new(name, Puppet::Forge::Cache.base_path, :encoding => 'ascii-8bit')
    end

    def download(uri, destination)
      @source.make_http_request(uri, destination)
      destination.flush and destination.close
    end

    def validate_checksum(file, checksum)
      if Digest::MD5.file(file.path).hexdigest != checksum
        raise RuntimeError, "Downloaded release for #{name} did not match expected checksum"
      end
    end

    def unpack(file, destination)
      begin
        Puppet::ModuleTool::Applications::Unpacker.unpack(file.path, destination)
      rescue Puppet::ExecutionFailure => e
        raise RuntimeError, "Could not extract contents of module archive: #{e.message}"
      end
    end
  end

  private

  def process(list)
    list.map { |release| ModuleRelease.new(self, release) }
  end
end
