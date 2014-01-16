module Puppet::ModuleTool::Errors

  class NoVersionsSatisfyError < ModuleToolError
    def initialize(options)
      @requested_name    = options[:requested_name]
      @requested_version = options[:requested_version]
      @installed_version = options[:installed_version]
      @conditions        = options[:conditions]
      @action            = options[:action]

      super "Could not #{@action} '#{@requested_name}' (#{vstring}); no version satisfies all dependencies"
    end

    def multiline
      message = []
      message << "Could not #{@action} module '#{@requested_name}' (#{vstring})"
      message << "  No version of '#{@requested_name}' can satisfy all dependencies"
      message << "    Use `puppet module #{@action} --ignore-dependencies` to #{@action} only this module"

      message.join("\n")
    end
  end

  class InvalidDependencyCycleError < ModuleToolError
    def initialize(options)
      @module_name       = options[:module_name]
      @requested_module  = options[:requested_module]
      @requested_version = options[:requested_version]
      @conditions        = options[:conditions]
      @source            = options[:source][1..-1]

      super "'#{@requested_module}' (#{v(@requested_version)}) requested; Invalid dependency cycle"
    end

    def multiline
      trace = []
      trace << "You specified '#{@source.first[:name]}' (#{v(@requested_version)})"
      trace += @source[1..-1].map { |m| "which depends on '#{m[:name]}' (#{v(m[:version])})" }

      message = []
      message << "Could not install module '#{@requested_module}' (#{v(@requested_version)})"
      message << "  No version of '#{@module_name}' will satisfy dependencies"
      message << trace.map { |s| "    #{s}" }.join(",\n")
      message << "    Use `puppet module install --force` to install this module anyway"

      message.join("\n")
    end
  end

  class NotInstalledError < ModuleToolError
    def initialize(options)
      @module_name = options[:module_name]
      @suggestions = options[:suggestions] || []
      @action      = options[:action]
      super "Could not #{@action} '#{@module_name}'; module is not installed"
    end

    def multiline
      message = []
      message << "Could not #{@action} module '#{@module_name}'"
      message << "  Module '#{@module_name}' is not installed"
      message += @suggestions.map do |suggestion|
        "    You may have meant `puppet module #{@action} #{suggestion}`"
      end
      message << "    Use `puppet module install` to install this module" if @action == :upgrade
      message.join("\n")
    end
  end

  class MultipleInstalledError < ModuleToolError
    def initialize(options)
      @module_name = options[:module_name]
      @modules     = options[:installed_modules]
      @action      = options[:action]
      super "Could not #{@action} '#{@module_name}'; module appears in multiple places in the module path"
    end

    def multiline
      message = []
      message << "Could not #{@action} module '#{@module_name}'"
      message << "  Module '#{@module_name}' appears multiple places in the module path"
      message += @modules.map do |mod|
        "    '#{@module_name}' (#{v(mod.version)}) was found in #{mod.modulepath}"
      end
      message << "    Use the `--modulepath` option to limit the search to specific directories"
      message.join("\n")
    end
  end

  class LocalChangesError < ModuleToolError
    def initialize(options)
      @module_name       = options[:module_name]
      @requested_version = options[:requested_version]
      @installed_version = options[:installed_version]
      @action            = options[:action]
      super "Could not #{@action} '#{@module_name}'; module has had changes made locally"
    end

    def multiline
      message = []
      message << "Could not #{@action} module '#{@module_name}' (#{vstring})"
      message << "  Installed module has had changes made locally"
      message << "    Use `puppet module #{@action} --force` to #{@action} this module anyway"
      message.join("\n")
    end
  end

  class InvalidModuleError < ModuleToolError
    def initialize(name, options)
      @name   = name
      @action = options[:action]
      @error  = options[:error]
      super "Could not #{@action} '#{@name}'; #{@error.message}"
    end

    def multiline
      message = []
      message << "Could not #{@action} module '#{@name}'"
      message << "  Failure trying to parse metadata"
      message << "    Original message was: #{@error.message}"
      message.join("\n")
    end
  end
end
