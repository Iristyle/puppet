require 'spec_helper'
require 'puppet/module_tool/applications'
require 'puppet_spec/module_tool/shared_functions'
require 'puppet_spec/module_tool/stub_source'
require 'semver'

describe Puppet::ModuleTool::Applications::Installer do
  include PuppetSpec::ModuleTool::SharedFunctions
  include PuppetSpec::Files
  include PuppetSpec::Fixtures

  before(:all) do
    @old_modulepath_ttl = Puppet::Node::Environment.attr_ttl(:modulepath)
    Puppet::Node::Environment.set_attr_ttl(:modulepath, 0)
  end

  after(:all) do
    Puppet::Node::Environment.set_attr_ttl(:modulepath, @old_modulepath_ttl)
  end

  before do
    FileUtils.mkdir_p(primary_dir)
    FileUtils.mkdir_p(secondary_dir)
    Puppet.settings[:vardir] = vardir
    Puppet.settings[:modulepath] = [ primary_dir, secondary_dir ].join(File::PATH_SEPARATOR)
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

  before do
    Semantic::Dependency.clear_sources
    installer = Puppet::ModuleTool::Applications::Installer.any_instance
    installer.stubs(:module_repository).returns(remote_source)
  end

  def installer(*args)
    Puppet::ModuleTool::Applications::Installer.new(*args)
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

    context 'with a tarball file' do
      let(:module) { fixtures('stdlib.tgz') }

      it 'installs the specified tarball' do
        subject.should include :result => :success
        graph_should_include 'puppetlabs-stdlib', nil => v('3.2.0')
      end

      context 'with --ignore-dependencies' do
        def options
          super.merge(:ignore_dependencies => true)
        end

        it 'installs the specified tarball' do
          remote_source.expects(:fetch).never
          subject.should include :result => :success
          graph_should_include 'puppetlabs-stdlib', nil => v('3.2.0')
        end
      end

      context 'with dependencies' do
        let(:module) { fixtures('java.tgz') }

        it 'installs the specified tarball' do
          subject.should include :result => :success
          graph_should_include 'puppetlabs-java', nil => v('1.0.0')
          graph_should_include 'puppetlabs-stdlib', nil => v('4.1.0')
        end

        context 'with --ignore-dependencies' do
          def options
            super.merge(:ignore_dependencies => true)
          end

          it 'installs the specified tarball without dependencies' do
            remote_source.expects(:fetch).never
            subject.should include :result => :success
            graph_should_include 'puppetlabs-java', nil => v('1.0.0')
            graph_should_include 'puppetlabs-stdlib', nil
          end
        end
      end
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

    context 'when depended upon' do
      before { preinstall('pmtacceptance-keystone', '2.1.0') }
      let(:module)  { 'pmtacceptance-mysql' }

      it 'installs an appropriate release' do
        subject.should include :result => :success
        graph_should_include 'pmtacceptance-mysql', nil => v('0.9.0')
      end

      context 'with a --version that can satisfy' do
        def options
          super.merge(:version => '0.8.0')
        end

        it 'installs a matching release' do
          subject.should include :result => :success
          graph_should_include 'pmtacceptance-mysql', nil => v('0.8.0')
        end
      end

      context 'with a --version that cannot satisfy' do
        def options
          super.merge(:version => '> 1.0.0')
        end

        it 'fails to install' do
          subject.should include :result => :failure
        end

        context 'with --ignore-dependencies' do
          def options
            super.merge(:ignore_dependencies => true)
          end

          it 'fails to install' do
            subject.should include :result => :failure
          end
        end

        context 'with --force' do
          def options
            super.merge(:force => true)
          end

          it 'installs an appropriate version' do
            subject.should include :result => :success
            graph_should_include 'pmtacceptance-mysql', nil => v('2.1.0')
          end
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
