# @api private
class Puppet::Settings::IniFile
  DEFAULT_SECTION_NAME = "main"

  def self.update(config_fh, &block)
    config = parse(config_fh)
    manipulator = Manipulator.new(config)
    yield manipulator
    config.write(config_fh)
  end

  def self.parse(config_fh)
    config = new
    config_fh.each_line do |line|
      case line
      when /^(\s*)\[(\w+)\](\s*)$/
        config << SectionLine.new($1, $2, $3)
      when /^(\s*)(\w+)(\s*=\s*)(.*?)(\s*)$/
        config << SettingLine.new($1, $2, $3, $4, $5)
      else
        config << Line.new(line)
      end
    end

    config
  end

  def initialize
    @lines = []
  end

  def <<(line)
    @lines << line
  end

  def each(&block)
    @lines.each(&block)
  end

  def setting(section, name)
    settings_in(section).find do |line|
      line.is_a?(SettingLine) && line.name == name
    end
  end

  def settings_in(section)
    section_lines = []
    current_section = DEFAULT_SECTION_NAME
    @lines.each do |line|
      if line.is_a?(SectionLine)
        current_section = line.name
      elsif current_section == section
        section_lines << line
      end
    end

    section_lines
  end

  def write(fh)
    fh.truncate(0)
    fh.rewind
    @lines.each do |line|
      line.write(fh)
    end
    fh.flush
  end

  class Manipulator
    def initialize(config)
      @config = config
    end

    def set(section, name, value)
      setting = @config.setting(section, name)
      if setting
        setting.value = value
      else
        @config << SectionLine.new("", section, "")
        @config << SettingLine.new("", name, "=", value, "")
      end
    end
  end

  Line = Struct.new(:text) do
    def write(fh)
      fh.puts(text)
    end
  end

  SettingLine = Struct.new(:prefix, :name, :infix, :value, :suffix) do
    def write(fh)
      fh.write(prefix)
      fh.write(name)
      fh.write(infix)
      fh.write(value)
      fh.puts(suffix)
    end
  end

  SectionLine = Struct.new(:prefix, :name, :suffix) do
    def write(fh)
      fh.write(prefix)
      fh.write("[")
      fh.write(name)
      fh.write("]")
      fh.puts(suffix)
    end
  end
end
