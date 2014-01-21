require 'spec_helper'
require 'puppet/module_tool/applications'
require 'puppet_spec/module_tool/shared_functions'
require 'puppet_spec/module_tool/stub_source'
require 'semver'

describe Puppet::ModuleTool::Applications::Installer, :unless => Puppet.features.microsoft_windows? do
  include PuppetSpec::ModuleTool::SharedFunctions
  include PuppetSpec::Files

  before do
    FileUtils.mkdir_p(primary_dir)
    FileUtils.mkdir_p(secondary_dir)
    Puppet::Node::Environment.set_attr_ttl(:modulepath, 0)
    Puppet.settings[:vardir] = vardir
    Puppet.settings[:modulepath] = [ primary_dir, secondary_dir ].join(':')
  end

  let(:vardir)   { tmpdir('upgrader') }
  let(:primary_dir) { File.join(vardir, "primary") }
  let(:secondary_dir) { File.join(vardir, "secondary") }
  let(:remote_source) { PuppetSpec::ModuleTool::StubSource.new }

  let(:install_dir) do
    mock("Puppet::ModuleTool::InstallDirectory").tap do |dir|
      dir.stubs(:prepare)
      dir.stubs(:target).returns(primary_dir)
    end
  end

  def installer(*args)
    Puppet::ModuleTool::Applications::Installer.new(*args).tap do
      Semantic::Dependency.clear_sources
      Semantic::Dependency.add_source(remote_source)
    end
  end

  context '#run' do
    let(:module) { 'pmtacceptance-stdlib' }

    def options
      Hash.new
    end

    let(:application) { installer(self.module, install_dir, options) }
    subject { application.run }

    it 'installs the specified module' do
      subject.should include :result => :success
      graph_should_include 'pmtacceptance-stdlib', nil => v('4.1.0')
    end

    context 'with dependencies' do
      let(:module) { 'pmtacceptance-apache' }

      it 'installs the specified module and its dependencies' do
        subject.should include :result => :success
        graph_should_include 'pmtacceptance-apache', nil => v('0.10.0')
        graph_should_include 'pmtacceptance-stdlib', nil => v('4.1.0')
      end

      context 'and using --ignore_dependencies' do
        def options
          super.merge(:ignore_dependencies => true)
        end

        it 'installs only the specified module' do
          subject.should include :result => :success
          graph_should_include 'pmtacceptance-apache', nil => v('0.10.0')
          graph_should_include 'pmtacceptance-stdlib', nil
        end
      end

      context 'that are already installed' do
        before { preinstall('pmtacceptance-stdlib', '4.1.0') }

        it 'installs only the specified module' do
          subject.should include :result => :success
          graph_should_include 'pmtacceptance-apache', nil => v('0.10.0')
          graph_should_include 'pmtacceptance-stdlib', :path => primary_dir
        end

        context '(outdated but suitable version)' do
          before { preinstall('pmtacceptance-stdlib', '2.3.0') }

          it 'installs only the specified module' do
            subject.should include :result => :success
            graph_should_include 'pmtacceptance-apache', nil => v('0.10.0')
            graph_should_include 'pmtacceptance-stdlib', :path => primary_dir
          end
        end

        context '(outdated and unsuitable version)' do
          before { preinstall('pmtacceptance-stdlib', '1.0.0') }

          it 'installs a version that is compatible with the installed dependencies' do
            subject.should include :result => :success
            graph_should_include 'pmtacceptance-apache', nil => v('0.0.4')
            graph_should_include 'pmtacceptance-stdlib', nil
          end
        end
      end

      context 'that are already installed in other modulepath directories' do
        before { preinstall('pmtacceptance-stdlib', '1.0.0', :into => secondary_dir) }
        let(:module) { 'pmtacceptance-apache' }

        context 'without dependency updates' do
          it 'installs the module only' do
            subject.should include :result => :success
            graph_should_include 'pmtacceptance-apache', nil => v('0.0.4')
            # graph_should_include 'pmtacceptance-stdlib', :path => secondary_dir
          end
        end

        context 'with dependency updates' do
          before { preinstall('pmtacceptance-stdlib', '2.0.0', :into => secondary_dir) }

          it 'installs the module and upgrades dependencies in-place' do
            subject.should include :result => :success
            graph_should_include 'pmtacceptance-apache', nil => v('0.10.0')
            graph_should_include 'pmtacceptance-stdlib', v('2.0.0') => v('2.6.0'), :path => secondary_dir
          end
        end
      end
    end

    context 'with a specified' do
      context 'version' do
        def options
          super.merge(:version => '3.0.0')
        end

        it 'installs the appropriate release' do
          subject.should include :result => :success
          graph_should_include 'pmtacceptance-stdlib', nil => v('3.0.0')
        end
      end

      context 'version range' do
        def options
          super.merge(:version => '3.x')
        end

        it 'installs the appropriate release' do
          subject.should include :result => :success
          graph_should_include 'pmtacceptance-stdlib', nil => v('3.2.0')
        end
      end
    end

    context 'when already installed' do
      before { preinstall('pmtacceptance-stdlib', '1.0.0') }

      context 'but matching the requested version' do
        it 'does nothing' do
          subject.should include :result => :noop
        end

        context 'with --force' do
          def options
            super.merge(:force => true)
          end

          it 'does reinstalls the module' do
            subject.should include :result => :success
            graph_should_include 'pmtacceptance-stdlib', v('1.0.0') => v('4.1.0')
          end
        end

        context 'with local changes' do
          before do
            release = application.send(:installed_modules)['pmtacceptance-stdlib']
            release.mod.stubs(:has_local_changes?).returns(true)
          end

          it 'does nothing' do
            subject.should include :result => :noop
          end

          context 'with --force' do
            def options
              super.merge(:force => true)
            end

            it 'does reinstalls the module' do
              subject.should include :result => :success
              graph_should_include 'pmtacceptance-stdlib', v('1.0.0') => v('4.1.0')
            end
          end
        end
      end

      context 'but not matching the requested version' do
        def options
          super.merge(:version => '2.x')
        end

        it 'fails if the module is not already installed' do
          subject.should include :result => :failure
          subject[:error].should include :oneline => "'pmtacceptance-stdlib' (v2.x) requested; 'pmtacceptance-stdlib' (v1.0.0) already installed"
        end

        context 'with --force' do
          def options
            super.merge(:force => true)
          end

          it 'does reinstalls the module' do
            subject.should include :result => :success
            graph_should_include 'pmtacceptance-stdlib', v('1.0.0') => v('2.6.0')
          end
        end
      end
    end
  end
end
