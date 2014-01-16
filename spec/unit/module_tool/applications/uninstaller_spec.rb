require 'spec_helper'
require 'puppet/module_tool'
require 'tmpdir'
require 'puppet_spec/module_tool/shared_functions'
require 'puppet_spec/module_tool/stub_source'

describe Puppet::ModuleTool::Applications::Uninstaller do
  include PuppetSpec::ModuleTool::SharedFunctions
  include PuppetSpec::Files

  before(:all) do
    @old_modulepath_ttl = Puppet::Node::Environment.attr_ttl(:modulepath)
    Puppet::Node::Environment.set_attr_ttl(:modulepath, 0)
  end

  after(:all) do
    Puppet::Node::Environment.set_attr_ttl(:modulepath, @old_modulepath_ttl)
  end

  describe "the behavior of the instances" do

    before do
      FileUtils.mkdir_p(primary_dir)
      FileUtils.mkdir_p(secondary_dir)
      Puppet.settings[:vardir] = vardir
      Puppet.settings[:modulepath] = [ primary_dir, secondary_dir ].join(':')
    end

    let(:vardir)   { tmpdir('upgrader') }
    let(:primary_dir) { File.join(vardir, "primary") }
    let(:secondary_dir) { File.join(vardir, "secondary") }
    let(:remote_source) { PuppetSpec::ModuleTool::StubSource.new }

    let(:module) { 'module-not_installed' }
    let(:application) { Puppet::ModuleTool::Applications::Uninstaller.new(self.module, options) }

    def options
      Hash.new
    end

    subject { application.run }

    context "when the module is not installed" do
      it "should fail" do
        subject.should include :result => :failure
      end
    end

    context "when the module is installed" do
      let(:module) { 'pmtacceptance-stdlib' }

      before { preinstall('pmtacceptance-stdlib', '1.0.0') }
      before { preinstall('pmtacceptance-apache', '0.0.4') }

      it "should uninstall the module" do
        subject[:affected_modules].first.forge_name.should == "pmtacceptance/stdlib"
      end

      it "should only uninstall the requested module" do
        subject[:affected_modules].length == 1
      end

      context 'in two modulepaths' do
        before { preinstall('pmtacceptance-stdlib', '2.0.0', :into => secondary_dir) }

        it "should uninstall fail if a module exists twice in the modpath" do
          subject.should include :result => :failure
        end
      end

      context "when options[:version] is specified" do
        def options
          super.merge(:version => '1.0.0')
        end

        it "should uninstall the module if the version matches" do
          subject[:affected_modules].length.should == 1
          subject[:affected_modules].first.version.should == "1.0.0"
        end

        context 'but not matched' do
          def options
            super.merge(:version => '2.0.0')
          end

          it "should not uninstall the module if the version does not match" do
            subject.should include :result => :failure
          end
        end
      end

      context "when the module has local changes" do
        before { Puppet::Module.any_instance.stubs(:has_local_changes?).returns(true) }

        it "should not uninstall the module" do
          subject.should include :result => :failure
        end
      end

      context "when uninstalling the module will cause broken dependencies" do
        before { preinstall('pmtacceptance-apache', '0.10.0') }

        it "should not uninstall the module" do
          subject.should include :result => :failure
        end
      end

      context "when using the --force flag" do

        def options
          super.merge(:force => true)
        end


        context "with local changes" do
          before { Puppet::Module.any_instance.stubs(:has_local_changes?).returns(true) }

          it "should ignore local changes" do
            subject[:affected_modules].length.should == 1
            subject[:affected_modules].first.forge_name.should == "pmtacceptance/stdlib"
          end
        end


        context "while depended upon" do
          before { preinstall('pmtacceptance-apache', '0.10.0') }

          it "should ignore broken dependencies" do
            subject[:affected_modules].length.should == 1
            subject[:affected_modules].first.forge_name.should == "pmtacceptance/stdlib"
          end
        end
      end
    end
  end
end
