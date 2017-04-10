test_name "Install packages and repositories on target machines..." do
require 'beaker/dsl/install_utils'
extend Beaker::DSL::InstallUtils

  SourcePath  = Beaker::DSL::InstallUtils::SourcePath
  GitURI      = Beaker::DSL::InstallUtils::GitURI
  GitHubSig   = Beaker::DSL::InstallUtils::GitHubSig

  tmp_repositories = []
  options[:install].each do |uri|
    raise(ArgumentError, "Missing GitURI argument. URI is nil.") if uri.nil?
    raise(ArgumentError, "#{uri} is not recognized.") unless(uri =~ GitURI)
    tmp_repositories << extract_repo_info_from(uri)
  end

  repositories = order_packages(tmp_repositories)

  versions = {}
  hosts.each_with_index do |host, index|
    on host, "echo #{GitHubSig} >> $HOME/.ssh/known_hosts"

    repositories.each do |repository|
      step "Install #{repository[:name]}"
      if repository[:path] =~ /^file:\/\/(.+)$/
        on host, "test -d #{SourcePath} || mkdir -p #{SourcePath}"
        source_dir = $1
        checkout_dir = "#{SourcePath}/#{repository[:name]}"
        on host, "rm -f #{checkout_dir}" # just the symlink, do not rm -rf !
        on host, "ln -s #{source_dir} #{checkout_dir}"
        on host, "cd #{checkout_dir} && if [ -f install.rb ]; then ruby ./install.rb ; else true; fi"
      else
        puppet_dir = host.tmpdir('puppet')
        on(host, "chmod 755 #{puppet_dir}")

        gemfile_contents = <<END
source '#{ENV["GEM_SOURCE"] || "https://rubygems.org"}'
gem '#{repository[:name]}', :git => '#{repository[:path]}', :ref => '#{ENV['SHA']}'
END
        case host['platform']
        when /windows/
          create_remote_file(host, "#{puppet_dir}/Gemfile", gemfile_contents)
          # bundle must be passed a Windows style path for a binstubs location
          binstubs_dir = on(host, "cygpath -m \"#{host['puppetbindir']}\"").stdout.chomp
          # note passing --shebang to bundle is not useful because Cygwin
          # already finds the Ruby interpreter OK with the standard shebang of:
          # !/usr/bin/env ruby
          # the problem is that a Cygwin style path is passed to the interpreter
          on host, "cd #{puppet_dir} && cmd.exe /c \"bundle install --system\ --binstubs #{binstubs_dir}\""
          # puppet.bat isn't written by Bundler, but facter.bat is - copy this generic file
          on host, "cd #{host['puppetbindir']} && test -f ./puppet.bat || cp ./facter.bat ./puppet.bat"
          # amend .bashrc with aliases so that Ruby binstubs always run through cmd
          # without them, Cygwin reads the shebang and causes errors like:
          # C:\cygwin64\bin\ruby.exe: No such file or directory -- /usr/bin/puppet (LoadError)
          # /usr/bin/puppet is a Cygwin style path that our custom Ruby build
          # does not understand - it expects a standard Windows path like c:\foo\puppet.rb
          # Rhere is no way to modify this behavior
          # see http://cygwin.1069669.n5.nabble.com/Pass-windows-style-paths-to-the-interpreter-from-the-shebang-line-td43870.html
          ['gem', 'facter', 'puppet'].each do |cmd_alias|
            on host, "echo \"alias #{cmd_alias}='C:/\\cygwin64/\\bin/\\#{cmd_alias}.bat'\" >> ~/.bashrc"
          end
        when /el-7/
          gemfile_contents = gemfile_contents + "gem 'json'\n"
          create_remote_file(host, "#{puppet_dir}/Gemfile", gemfile_contents)
          on host, "cd #{puppet_dir} && bundle install --system --binstubs #{host['puppetbindir']}"
        when /solaris/
          create_remote_file(host, "#{puppet_dir}/Gemfile", gemfile_contents)
          on host, "cd #{puppet_dir} && bundle install --system --binstubs #{host['puppetbindir']} --shebang #{host['puppetbindir']}/ruby"
        else
          create_remote_file(host, "#{puppet_dir}/Gemfile", gemfile_contents)
          on host, "cd #{puppet_dir} && bundle install --system --binstubs #{host['puppetbindir']}"
        end
      end
    end
  end

  step "Hosts: create basic puppet.conf" do
    hosts.each do |host|
      confdir = host.puppet['confdir']
      on host, "mkdir -p #{confdir}"
      puppetconf = File.join(confdir, 'puppet.conf')

      if host['roles'].include?('agent')
        on host, "echo '[agent]' > '#{puppetconf}' && " +
                 "echo server=#{master} >> '#{puppetconf}'"
      else
        on host, "touch '#{puppetconf}'"
      end
    end
  end

  step "Hosts: create environments directory like AIO does" do
    hosts.each do |host|
      codedir = host.puppet['codedir']
      on host, "mkdir -p #{codedir}/environments/production/manifests"
      on host, "mkdir -p #{codedir}/environments/production/modules"
      on host, "chmod -R 755 #{codedir}"
    end
  end
end
