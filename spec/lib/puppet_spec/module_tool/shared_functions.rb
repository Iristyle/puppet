module PuppetSpec
  module ModuleTool
    module SharedFunctions
      def remote_release(name, version)
        remote_source.available_releases[name][version]
      end

      def preinstall(name, version, options = { :into => primary_dir })
        release = remote_release(name, version)
        raise "Could not preinstall #{name} v#{version}" if release.nil?

        name = release.name[/-(.*)/, 1]
        moddir = File.join(options[:into], name)
        FileUtils.mkdir_p(moddir)
        File.open(File.join(moddir, 'metadata.json'), 'w') do |file|
          file.puts release.metadata.to_json
        end
      end

      def graph_should_include(name, options)
        releases = flatten_graph(subject[:graph] || [])
        release = releases.find { |x| x[:name] == name }

        if options.nil?
          release.should be_nil
        else
          from = options.keys.find { |k| k.nil? || k.is_a?(Semantic::Version) }
          to   = options.delete(from)

          if to or from
            options[:previous_version] ||= from
            options[:version] ||= to
          end

          release.should include options
        end
      end

      def flatten_graph(graph)
        graph + graph.map { |sub| flatten_graph(sub[:dependencies]) }.flatten
      end

      def v(str)
        Semantic::Version.parse(str)
      end
    end
  end
end