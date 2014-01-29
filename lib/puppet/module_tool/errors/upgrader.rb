module Puppet::ModuleTool::Errors

  class UpgradeError < ModuleToolError
    def initialize(msg)
      @action = :upgrade
      super
    end
  end

  class VersionAlreadyInstalledError < UpgradeError
    attr_reader :newer_versions

    def initialize(options)
      @module_name       = options[:module_name]
      @requested_version = options[:requested_version]
      @installed_version = options[:installed_version]
      @dependency_name   = options[:dependency_name]
      @newer_versions    = options[:newer_versions]
      @possible_culprits = options[:possible_culprits]
      super "Could not upgrade '#{@module_name}'; more recent versions not found"
    end

    def multiline
      message = []
      message << "Could not upgrade module '#{@module_name}' (#{vstring})"
      if @newer_versions.empty?
        message << "  The installed version is already the latest version matching #{vstring}"
      else
        message << "  There are #{@newer_versions.length} newer versions"
        message << "    No combination of dependency upgrades would satisfy all dependencies"
        unless @possible_culprits.empty?
          message << "    Dependencies will not be automatically upgraded across major versions"
          message << "    Upgrading one or more of these modules may permit the upgrade to succeed:"
          @possible_culprits.each do |name|
            message << "    - #{name}"
          end
        end
      end
      message << "    Use `puppet module upgrade --force` to upgrade only this module"
      message.join("\n")
    end
  end

  class NoCandidateReleasesError < UpgradeError
    def initialize(options)
      @module_name       = options[:module_name]
      @requested_version = options[:requested_version]
      @installed_version = options[:installed_version]
      @source            = options[:source]

      if @requested_version == :latest
        super "Could not upgrade '#{@module_name}'; no releases are available from #{@source}"
      else
        super "Could not upgrade '#{@module_name}'; no releases matching '#{@requested_version}' are available from #{@source}"
      end
    end

    def multiline
      message = []
      message << "Could not upgrade '#{@module_name}' (#{vstring})"

      if @requested_version == :latest
        message << "  No releases are available from #{@source}"
        message << "    Does '#{@module_name}' have at least one published release?"
      else
        message << "  No releases matching '#{@requested_version}' are available from #{@source}"
      end

      message.join("\n")
    end
  end
end
