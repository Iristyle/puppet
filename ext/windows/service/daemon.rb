#!/usr/bin/env ruby

require 'fileutils'
require 'win32/daemon'
require 'win32/dir'
require 'win32/process'

class WindowsDaemon < Win32::Daemon
  CREATE_NEW_CONSOLE          = 0x00000010
  EVENTLOG_ERROR_TYPE         = 0x0001
  EVENTLOG_WARNING_TYPE       = 0x0002
  EVENTLOG_INFORMATION_TYPE   = 0x0004

  LOG_FILE =  File.expand_path(File.join(Dir::COMMON_APPDATA, 'PuppetLabs', 'puppet', 'var', 'log', 'windows.log'))
  LEVELS = [:debug, :info, :notice, :err]
  LEVELS.each do |level|
    define_method("log_#{level}") do |msg|
      log(msg, level)
    end
  end

  def service_init
    FileUtils.mkdir_p(File.dirname(LOG_FILE))
  end

  def service_main(*argv)
    args = argv.join(' ')
    @loglevel = LEVELS.index(argv.index('--debug') ? :debug : :notice)

    log_notice("Starting service: #{args}")

    while running? do
      return if state != RUNNING

      log_notice('Service running')

      basedir = File.expand_path(File.join(File.dirname(__FILE__), '..'))
      puppet = File.join(basedir, 'bin', 'puppet.bat')
      unless File.exists?(puppet)
        log_err("File not found: '#{puppet}'")
        return
      end

      log_debug("Using '#{puppet}'")
      begin
        runinterval = %x{ "#{puppet}" agent --configprint runinterval }.to_i
        if runinterval == 0
          runinterval = 1800
          log_err("Failed to determine runinterval, defaulting to #{runinterval} seconds")
        end
      rescue Exception => e
        log_exception(e)
        runinterval = 1800
      end

      if state == RUNNING or state == IDLE
        log_notice("Executing agent with arguments: #{args}")
        pid = Process.create(:command_line => "\"#{puppet}\" agent --onetime #{args}", :creation_flags => CREATE_NEW_CONSOLE).process_id
        log_debug("Process created: #{pid}")
      else
        log_debug("Service is paused.  Not invoking Puppet agent")
      end

      log_debug("Service waiting for #{runinterval} seconds")
      sleep(runinterval)
      log_debug('Service resuming')
    end

    log_notice('Service stopped')
  rescue Exception => e
    log_exception(e)
  end

  def service_stop
    log_notice('Service stopping')
    Thread.main.wakeup
  end

  def service_pause
    log_notice('Service pausing')
  end

  def service_resume
    log_notice('Service resuming')
  end

  def service_shutdown
    log_notice('Host shutting down')
  end

  # Interrogation handler is just for debug.  Can be commented out or removed entirely.
  # def service_interrogate
  #   log_debug('Service is being interrogated')
  # end

  def log_exception(e)
    log_err(e.message)
    log_err(e.backtrace.join("\n"))
  end

  def log(msg, level)
    if LEVELS.index(level) >= @loglevel
      if (@LOG_TO_FILE)
        File.open(LOG_FILE, 'a') { |f| f.puts("#{Time.now} Puppet (#{level}): #{msg}") }
      end

      case level
        when :debug, :info, :notice
          report_windows_event(EVENTLOG_INFORMATION_TYPE,0x01,msg.to_s)
        when :err
          report_windows_event(EVENTLOG_ERROR_TYPE,0x03,msg.to_s)
        else
          report_windows_event(EVENTLOG_WARNING_TYPE,0x02,msg.to_s)
      end
    end
  end

  def report_windows_event(type,id,message)
    begin
      eventlog = nil
      eventlog = Win32::EventLog.open("Application")
      eventlog.report_event(
        :source      => "Puppet",
        :event_type  => type,   # EVENTLOG_ERROR_TYPE, etc
        :event_id    => id,     # 0x01 or 0x02, 0x03 etc.
        :data        => message # "the message"
      )
    rescue Exception => e
      # Ignore all errors
    ensure
      if (!eventlog.nil?)
        eventlog.close
      end
    end
  end
end

if __FILE__ == $0
  WindowsDaemon.mainloop
end
