require 'spec_helper'
require 'puppet/module_tool/applications'
require 'puppet_spec/module_tool/shared_functions'
require 'puppet_spec/module_tool/stub_source'
require 'semver'

describe Puppet::ModuleTool::Applications::Upgrader do
  include PuppetSpec::ModuleTool::SharedFunctions
  include PuppetSpec::Files

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

  before do
    Semantic::Dependency.clear_sources
    installer = Puppet::ModuleTool::Applications::Upgrader.any_instance
    installer.stubs(:module_repository).returns(remote_source)
  end

  def upgrader(name, options = {})
    Puppet::ModuleTool::Applications::Upgrader.new(name, options)
  end

  describe '#run' do
    let(:module) { 'pmtacceptance-stdlib' }

    def options
      Hash.new
    end

    let(:application) { upgrader(self.module, options) }
    subject { application.run }

    it 'fails if the module is not already installed' do
      subject.should include :result => :failure
      subject[:error].should include :oneline => "Could not upgrade '#{self.module}'; module is not installed"
    end

    context 'for an installed module' do
      context 'without dependencies' do
        before { preinstall('pmtacceptance-stdlib', '1.0.0') }

        context 'without options' do
          it 'properly upgrades the module' do
            subject.should include :result => :success
            graph_should_include 'pmtacceptance-stdlib', v('1.0.0') => v('4.1.0')
          end
        end

        context 'with version range' do
          def options
            super.merge(:version => '3.x')
          end

          context 'not matching the installed version' do
            it 'properly upgrades the module within that version range' do
              subject.should include :result => :success
              graph_should_include 'pmtacceptance-stdlib', v('1.0.0') => v('3.2.0')
            end
          end

          context 'matching the installed version' do
            context 'with more recent version' do
              before { preinstall('pmtacceptance-stdlib', '3.0.0')}

              it 'properly upgrades the module within that version range' do
                subject.should include :result => :success
                graph_should_include 'pmtacceptance-stdlib', v('3.0.0') => v('3.2.0')
              end
            end

            context 'without more recent version' do
              before { preinstall('pmtacceptance-stdlib', '3.2.0')}

              context 'without options' do
                it 'declines to upgrade' do
                  subject.should include :result => :noop
                end
              end

              context 'with --force' do
                def options
                  super.merge(:force => true)
                end

                it 'performs the upgrade' do
                  subject.should include :result => :success
                  graph_should_include 'pmtacceptance-stdlib', v('3.2.0') => v('3.2.0')
                end
              end
            end
          end
        end
      end

      context 'that is depended upon' do
        before { preinstall('pmtacceptance-keystone', '2.1.0') }
        before { preinstall('pmtacceptance-mysql', '0.9.0') }

        let(:module) { 'pmtacceptance-mysql' }

        context 'and out of date' do
          before { preinstall('pmtacceptance-mysql', '0.8.0') }

          it 'properly upgrades the module within that version range' do
            subject.should include :result => :success
            graph_should_include 'pmtacceptance-mysql', v('0.8.0') => v('0.9.0')
          end
        end

        context 'and up to date' do
          it 'declines to upgrade' do
            subject.should include :result => :failure
          end
        end

        context 'when specifying a violating version range' do
          def options
            super.merge(:version => '2.1.0')
          end

          it 'fails to upgrade the module' do
            # TODO: More helpful error message?
            subject.should include :result => :failure
            subject[:error].should include :oneline => "Could not upgrade '#{self.module}' (v0.9.0 -> v2.1.0); no version satisfies all dependencies"
          end

          context 'using --force' do
            def options
              super.merge(:force => true)
            end

            it 'properly upgrades the module within that version range' do
              subject.should include :result => :success
              graph_should_include 'pmtacceptance-mysql', v('0.9.0') => v('2.1.0')
            end
          end
        end
      end

      context 'with local changes' do
        before { preinstall('pmtacceptance-stdlib', '1.0.0') }
        before do
          release = application.send(:installed_modules)['pmtacceptance-stdlib']
          release.mod.stubs(:has_local_changes?).returns(true)
        end

        it 'fails to upgrade' do
          subject.should include :result => :failure
          subject[:error].should include :oneline => "Could not upgrade '#{self.module}'; module has had changes made locally"
        end
      end

      context 'with dependencies' do
        context 'that are unsatisfied' do
          def options
            super.merge(:version => '0.1.1')
          end

          before { preinstall('pmtacceptance-apache', '0.0.3') }
          let(:module) { 'pmtacceptance-apache' }

          it 'upgrades the module and installs the relevant dependencies' do
            subject.should include :result => :success
            graph_should_include 'pmtacceptance-apache', v('0.0.3') => v('0.1.1')
            graph_should_include 'pmtacceptance-stdlib', nil => v('4.1.0'), :action => :install
          end
        end

        context 'with older major versions' do
          before { preinstall('pmtacceptance-apache', '0.0.3') }
          before { preinstall('pmtacceptance-stdlib', '1.0.0') }
          let(:module) { 'pmtacceptance-apache' }

          it 'limits the upgrade to versions that get along' do
            subject.should include :result => :success
            graph_should_include 'pmtacceptance-apache', v('0.0.3') => v('0.0.4')
          end

          context 'using --ignore_dependencies' do
            def options
              super.merge(:force => true)
            end

            it 'properly upgrades the module' do
              subject.should include :result => :success
              graph_should_include 'pmtacceptance-apache', v('0.0.3') => v('0.10.0')
            end
          end
        end

        context 'with satisfying major versions' do
          before { preinstall('pmtacceptance-apache', '0.0.3') }
          before { preinstall('pmtacceptance-stdlib', '2.0.0') }
          let(:module) { 'pmtacceptance-apache' }

          it 'upgrades the module and upgrades the relevant dependencies' do
            subject.should include :result => :success
            graph_should_include 'pmtacceptance-apache', v('0.0.3') => v('0.10.0')
            graph_should_include 'pmtacceptance-stdlib', v('2.0.0') => v('2.6.0')
          end
        end

        context 'with satisfying versions' do
          before { preinstall('pmtacceptance-apache', '0.0.3') }
          before { preinstall('pmtacceptance-stdlib', '2.4.0') }
          let(:module) { 'pmtacceptance-apache' }

          it 'upgrades the module only' do
            subject.should include :result => :success
            graph_should_include 'pmtacceptance-apache', v('0.0.3') => v('0.10.0')
            graph_should_include 'pmtacceptance-stdlib', nil
          end
        end

        context 'with current versions' do
          before { preinstall('pmtacceptance-apache', '0.0.3') }
          before { preinstall('pmtacceptance-stdlib', '2.6.0') }
          let(:module) { 'pmtacceptance-apache' }

          it 'upgrades the module only' do
            subject.should include :result => :success
            graph_should_include 'pmtacceptance-apache', v('0.0.3') => v('0.10.0')
            graph_should_include 'pmtacceptance-stdlib', nil
          end
        end

        context 'with shared dependencies' do
          before { preinstall('pmtacceptance-bacula', '0.0.1') }
          before { preinstall('pmtacceptance-mysql', '0.9.0') }
          before { preinstall('pmtacceptance-keystone', '2.1.0') }

          let(:module) { 'pmtacceptance-bacula' }

          it 'upgrades the module to an acceptable compromise', :focus => true do
            subject.should include :result => :success
            graph_should_include 'pmtacceptance-bacula', v('0.0.1') => v('0.0.2')
          end

          context 'using --force' do
            def options
              super.merge(:force => true)
            end

            it 'properly upgrades the module' do
              subject.should include :result => :success
              graph_should_include 'pmtacceptance-bacula', v('0.0.1') => v('0.0.3')
            end
          end
        end

        context 'in other modulepath directories' do
          before { preinstall('pmtacceptance-apache', '0.0.3') }
          before { preinstall('pmtacceptance-stdlib', '1.0.0', :into => secondary_dir) }
          let(:module) { 'pmtacceptance-apache' }

          context 'without dependency updates' do
            it 'upgrades the module only' do
              subject.should include :result => :success
              graph_should_include 'pmtacceptance-apache', v('0.0.3') => v('0.0.4')
              graph_should_include 'pmtacceptance-stdlib', nil
            end
          end

          context 'with dependency updates' do
            before { preinstall('pmtacceptance-stdlib', '2.0.0', :into => secondary_dir) }

            it 'upgrades the module and dependencies in-place' do
              subject.should include :result => :success
              graph_should_include 'pmtacceptance-apache', v('0.0.3') => v('0.10.0')
              graph_should_include 'pmtacceptance-stdlib', v('2.0.0') => v('2.6.0'), :path => secondary_dir
            end
          end
        end
      end
    end

    context 'when the module has a PE version requirement', :pe_specific => true do
      let(:module) { 'pmtacceptance-pe_version' }
      before { preinstall('pmtacceptance-pe_version', '1.0.0') }
      before { Puppet.stubs(:enterprise?).returns(true) }

      context 'when the PE version matches' do
        before { Puppet.stubs(:pe_version).returns('1.3.0') }

        it 'installs an appropriate version' do
          subject.should include :result => :success
          graph_should_include 'pmtacceptance-pe_version', v('1.0.0') => v('1.0.1')
        end
      end

      context 'when the PE version does not match' do
        before { Puppet.stubs(:pe_version).returns('3.3.0') }

        it 'fails to install' do
          subject.should include :result => :failure
        end

        context 'using --force' do
          def options
            super.merge(:force => true)
          end

          it 'installs an appropriate version' do
            subject.should include :result => :success
            graph_should_include 'pmtacceptance-pe_version', v('1.0.0') => v('1.0.1')
          end
        end
      end
    end
  end
end
