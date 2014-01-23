require 'pathname'

require 'puppet/forge'
require 'puppet/module_tool'
require 'puppet/module_tool/shared_behaviors'
require 'puppet/module_tool/install_directory'
require 'puppet/module_tool/installed_modules'

module Puppet::ModuleTool
  module Applications
    class Upgrader < Application

      include Puppet::ModuleTool::Errors

      def initialize(name, options)
        super(options)

        @action              = :upgrade
        @environment         = Puppet::Node::Environment.new(Puppet.settings[:environment])
        @name                = name
        @ignore_dependencies = forced? || options[:ignore_dependencies]

        Semantic::Dependency.add_source(installed_modules_source)
        Semantic::Dependency.add_source(module_repository)
      end

      def run
        name = @name.tr('/', '-')
        version = options[:version] || '>= 0'

        results = {
          :action => :upgrade,
          :requested_version => options[:version] || :latest,
        }

        begin
          if installed_modules_source.fetch(name).empty?
            raise NotInstalledError, results.merge(:module_name => name)
          end

          mod = installed_modules[name].mod
          results[:installed_version] = Semantic::Version.parse(mod.version)
          dir = Pathname.new(mod.modulepath)

          vstring = mod.version ? "v#{mod.version}" : '???'
          Puppet.notice "Found '#{name}' (#{colorize(:cyan, vstring)}) in #{dir} ..."
          unless forced?
            if mod.has_metadata? && mod.has_local_changes?
              raise LocalChangesError,
                :action            => :upgrade,
                :module_name       => name,
                :requested_version => results[:requested_version],
                :installed_version => mod.version
            end
          end


          Puppet::Forge::Cache.clean

          Puppet.notice "Downloading from #{module_repository.host} ..."
          if @ignore_dependencies
            graph = build_single_module_graph(name, version)
          else
            graph = build_dependency_graph(name, version)
          end

          add_module_name_constraints_to_graph(graph)
          add_requirements_constraints_to_graph(graph)

          installed_modules.each do |mod, release|
            mod = mod.tr('/', '-')
            next if mod == name

            version = release.version

            unless forced?
              # Since upgrading already installed modules can be troublesome,
              # we'll place constraints on the graph for each installed
              # module, locking it to upgrades within the same major version.
              ">=#{version} #{version.major}.x".tap do |range|
                graph.add_constraint('installed', mod, range) do |node|
                  Semantic::VersionRange.parse(range).include? node.version
                end
              end

              release.mod.dependencies.each do |dep|
                dep_name = dep['name'].tr('/', '-')

                dep['version_requirement'].tap do |range|
                  graph.add_constraint("#{mod} constraint", dep_name, range) do |node|
                    Semantic::VersionRange.parse(range).include? node.version
                  end
                end
              end
            end
          end

          begin
            Puppet.info "Resolving dependencies ..."
            releases = Semantic::Dependency.resolve(graph)
          rescue Semantic::Dependency::UnsatisfiableGraph
            raise NoVersionsSatisfyError, results.merge(:requested_name => name)
          end

          child = releases.find { |x| x.name == name }
          unless forced?
            if child.version <= results[:installed_version]
              versions = graph.dependencies[name].map { |r| r.version }
              newer_versions = versions.select { |v| v > results[:installed_version] }

              raise VersionAlreadyInstalledError,
                :module_name       => name,
                :requested_version => results[:requested_version],
                :installed_version => results[:installed_version],
                :newer_versions    => newer_versions,
                :possible_culprits => installed_modules_source.fetched.reject { |x| x == name }
            end
          end

          Puppet.info "Preparing to upgrade ..."
          releases.each { |release| release.prepare }

          Puppet.notice 'Upgrading -- do not interrupt ...'
          releases.each do |release|
            if installed = installed_modules[release.name]
              release.install(Pathname.new(installed.mod.modulepath))
            else
              release.install(dir)
            end
          end

          results[:result] = :success
          results[:base_dir] = releases.first.install_dir
          results[:affected_modules] = releases
          results[:graph] = [ build_install_graph(releases.first, releases) ]

        rescue VersionAlreadyInstalledError => e
          results[:result] = (e.newer_versions.empty? ? :noop : :failure)
          results[:error] = { :oneline => e.message, :multiline => e.multiline }
        rescue => e
          results[:error] = {
            :oneline   => e.message,
            :multiline => e.respond_to?(:multiline) ? e.multiline : [e.to_s, e.backtrace].join("\n")
          }
        ensure
          results[:result] ||= :failure
        end

        results
      end

      private
      def module_repository
        @repo ||= Puppet::Forge.new
      end

      def installed_modules_source
        @installed ||= Puppet::ModuleTool::InstalledModules.new
      end

      def installed_modules
        installed_modules_source.modules
      end

      def build_single_module_graph(name, version)
        range = Semantic::VersionRange.parse(version)
        graph = Semantic::Dependency::Graph.new(name => range)
        releases = Semantic::Dependency.fetch_releases(name)
        releases.each { |release| release.dependencies.clear }
        graph << releases
      end

      def build_dependency_graph(name, version)
        Semantic::Dependency.query(name => version)
      end

      def build_install_graph(release, installed, graphed = [])
        previous = installed_modules[release.name]
        previous = previous.version if previous

        action = :upgrade
        unless previous && previous != release.version
          action = :install
        end

        graphed << release

        dependencies = release.dependencies.values.map do |deps|
          dep = (deps & installed).first
          if dep == installed_modules[dep.name]
            next
          end

          if dep && !graphed.include?(dep)
            build_install_graph(dep, installed, graphed)
          end
        end.compact

        return {
          :release          => release,
          :name             => release.name,
          :path             => release.install_dir,
          :dependencies     => dependencies.compact,
          :version          => release.version,
          :previous_version => previous,
          :action           => action,
        }
      end

      include Puppet::ModuleTool::Shared
    end
  end
end
