# encoding: UTF-8

require 'spec_helper'
require 'puppet/face'
require 'puppet/module_tool'
require 'puppet_spec/modules'

describe "puppet module list" do
  include PuppetSpec::Files

  before do
    dir = tmpdir("deep_path")

    @modpath1 = File.join(dir, "modpath1")
    @modpath2 = File.join(dir, "modpath2")
    @modulepath = "#{@modpath1}#{File::PATH_SEPARATOR}#{@modpath2}"
    Puppet.settings[:modulepath] = @modulepath

    FileUtils.mkdir_p(@modpath1)
    FileUtils.mkdir_p(@modpath2)
  end

  it "should return an empty list per dir in path if there are no modules" do
    Puppet.settings[:modulepath] = @modulepath
    Puppet::Face[:module, :current].list.should == {
      @modpath1 => [],
      @modpath2 => []
    }
  end

  it "should include modules separated by the environment's modulepath" do
    foomod1 = PuppetSpec::Modules.create('foo', @modpath1)
    barmod1 = PuppetSpec::Modules.create('bar', @modpath1)
    foomod2 = PuppetSpec::Modules.create('foo', @modpath2)

    env = Puppet::Node::Environment.new

    Puppet::Face[:module, :current].list.should == {
      @modpath1 => [
        Puppet::Module.new('bar', barmod1.path, env),
        Puppet::Module.new('foo', foomod1.path, env)
      ],
      @modpath2 => [Puppet::Module.new('foo', foomod2.path, env)]
    }
  end

  it "should use the specified environment" do
    foomod = PuppetSpec::Modules.create('foo', @modpath1)
    barmod = PuppetSpec::Modules.create('bar', @modpath1)

    usedenv = Puppet::Node::Environment.new('useme')
    usedenv.modulepath = [@modpath1, @modpath2]

    Puppet::Face[:module, :current].list(:environment => 'useme').should == {
      @modpath1 => [
        Puppet::Module.new('bar', barmod.path, usedenv),
        Puppet::Module.new('foo', foomod.path, usedenv)
      ],
      @modpath2 => []
    }
  end

  it "should use the specified modulepath" do
    foomod = PuppetSpec::Modules.create('foo', @modpath1)
    barmod = PuppetSpec::Modules.create('bar', @modpath2)

    Puppet::Face[:module, :current].list(:modulepath => "#{@modpath1}#{File::PATH_SEPARATOR}#{@modpath2}").should == {
      @modpath1 => [ Puppet::Module.new('foo', foomod.path, Puppet::Node::Environment.new) ],
      @modpath2 => [ Puppet::Module.new('bar', barmod.path, Puppet::Node::Environment.new) ]
    }
  end

  it "should use the specified modulepath over the specified environment in place of the environment's default path" do
    foomod1 = PuppetSpec::Modules.create('foo', @modpath1)
    barmod2 = PuppetSpec::Modules.create('bar', @modpath2)
    env = Puppet::Node::Environment.new('myenv')
    env.modulepath = ['/tmp/notused']

    list = Puppet::Face[:module, :current].list(:environment => 'myenv', :modulepath => "#{@modpath1}#{File::PATH_SEPARATOR}#{@modpath2}")

    # Changing Puppet[:modulepath] causes Puppet::Node::Environment.new('myenv')
    # to have a different object_id than the env above
    env = Puppet::Node::Environment.new('myenv')
    list.should == {
      @modpath1 => [ Puppet::Module.new('foo', foomod1.path, env) ],
      @modpath2 => [ Puppet::Module.new('bar', barmod2.path, env) ]
    }
  end

  describe "inline documentation" do
    subject { Puppet::Face[:module, :current].get_action :list }

    its(:summary)     { should =~ /list.*module/im }
    its(:description) { should =~ /list.*module/im }
    its(:returns)     { should =~ /hash of paths to module objects/i }
    its(:examples)    { should_not be_empty }
  end

  describe "when rendering" do
    it "should explicitly state when a modulepath is empty" do
      empty_modpath = tmpdir('empty')
      Puppet::Face[:module, :current].list_when_rendering_console(
        { empty_modpath => [] },
        {:modulepath => empty_modpath}
      ).should == <<-HEREDOC.gsub('        ', '')
        #{empty_modpath} (no modules installed)
      HEREDOC
    end

    it "should print both modules with and without metadata" do
      modpath = tmpdir('modpath')
      Puppet.settings[:modulepath] = modpath
      PuppetSpec::Modules.create('nometadata', modpath)
      PuppetSpec::Modules.create('metadata', modpath, :metadata => {:author => 'metaman'})

      dependency_tree = Puppet::Face[:module, :current].list

      output = Puppet::Face[:module, :current].
        list_when_rendering_console(dependency_tree, {})

      output.should == <<-HEREDOC.gsub('        ', '')
        #{modpath}
        ├── metaman-metadata (\e[0;36mv9.9.9\e[0m)
        └── nometadata (\e[0;36m???\e[0m)
        HEREDOC
    end

    it "should print the modulepaths in the order they are in the modulepath setting" do
      path1 = tmpdir('b')
      path2 = tmpdir('c')
      path3 = tmpdir('a')

      sep = File::PATH_SEPARATOR
      Puppet.settings[:modulepath] = "#{path1}#{sep}#{path2}#{sep}#{path3}"

      Puppet::Face[:module, :current].list_when_rendering_console(
        {
          path2 => [],
          path3 => [],
          path1 => [],
        },
        {}
      ).should == <<-HEREDOC.gsub('        ', '')
        #{path1} (no modules installed)
        #{path2} (no modules installed)
        #{path3} (no modules installed)
      HEREDOC
    end

    it "should print dependencies as a tree" do
      PuppetSpec::Modules.create('dependable', @modpath1, :metadata => { :version => '0.0.5'})
      PuppetSpec::Modules.create(
        'other_mod',
        @modpath1,
        :metadata => {
          :version => '1.0.0',
          :dependencies => [{
            "version_requirement" => ">= 0.0.5",
            "name"                => "puppetlabs/dependable"
          }]
        }
      )

      dependency_tree = Puppet::Face[:module, :current].list

      output = Puppet::Face[:module, :current].list_when_rendering_console(
        dependency_tree,
        {:tree => true}
      )

      output.should == <<-HEREDOC.gsub('        ', '')
        #{@modpath1}
        └─┬ puppetlabs-other_mod (\e[0;36mv1.0.0\e[0m)
          └── puppetlabs-dependable (\e[0;36mv0.0.5\e[0m)
        #{@modpath2} (no modules installed)
        HEREDOC
    end

    it "should print both modules with and without metadata as a tree" do
      modpath = tmpdir('modpath')
      Puppet.settings[:modulepath] = modpath
      PuppetSpec::Modules.create('nometadata', modpath)
      PuppetSpec::Modules.create('metadata', modpath, :metadata => {:author => 'metaman'})

      dependency_tree = Puppet::Face[:module, :current].list

      output = Puppet::Face[:module, :current].
        list_when_rendering_console(dependency_tree, { :tree => true })

      output.should == <<-HEREDOC.gsub('        ', '')
        #{modpath}
        ├── metaman-metadata (\e[0;36mv9.9.9\e[0m)
        └── nometadata (\e[0;36m???\e[0m)
        HEREDOC
    end

    it "should warn about missing dependencies" do
      PuppetSpec::Modules.create('depender', @modpath1, :metadata => {
        :version => '1.0.0',
        :dependencies => [{
          "version_requirement" => ">= 0.0.5",
          "name"                => "puppetlabs/dependable"
        }]
      })

      warning_expectations = [
        regexp_matches(/Missing dependency 'puppetlabs-dependable'/),
        regexp_matches(/'puppetlabs-depender' \(v1\.0\.0\) requires 'puppetlabs-dependable' \(>= 0\.0\.5\)/)
      ]

      Puppet.expects(:warning).with(all_of(*warning_expectations))

      Puppet::Face[:module, :current].list_when_rendering_console(
        Puppet::Face[:module, :current].list, {:tree => true}
      )
    end

    it "should warn about out of range dependencies" do
      PuppetSpec::Modules.create('dependable', @modpath1, :metadata => { :version => '0.0.1'})
      PuppetSpec::Modules.create('depender', @modpath1, :metadata => {
        :version => '1.0.0',
        :dependencies => [{
          "version_requirement" => ">= 0.0.5",
          "name"                => "puppetlabs/dependable"
        }]
      })

      warning_expectations = [
        regexp_matches(/Module 'puppetlabs-dependable' \(v0\.0\.1\) fails to meet some dependencies/),
        regexp_matches(/'puppetlabs-depender' \(v1\.0\.0\) requires 'puppetlabs-dependable' \(>= 0\.0\.5\)/)
      ]

      Puppet.expects(:warning).with(all_of(*warning_expectations))

      Puppet::Face[:module, :current].list_when_rendering_console(
        Puppet::Face[:module, :current].list, {:tree => true}
      )
    end

    context "when running PE" do
      before(:each) do
        Puppet.stubs(:enterprise?).returns(true)
        Puppet.stubs(:pe_version).returns('3.2.0')
      end

      it "should warn when unsatisifed PE requirements are present" do
        PuppetSpec::Modules.create('pe_dependable', @modpath1, :metadata => {
          :version => '0.0.5',
          :requirements => [{
            "name" => "PE",
            "version_requirement" => "2.x"
          }]
        })

        Puppet.expects(:warning).with(regexp_matches(/'pe_dependable' \(v0\.0\.5\) requires Puppet Enterprise 2\.x/))

        Puppet::Face[:module, :current].list_when_rendering_console(
          Puppet::Face[:module, :current].list, {:tree => true}
        )
      end

      context "when multiple PE requirements are declared on a module" do
        it "should warn about the first unsatisfied requirement" do
          PuppetSpec::Modules.create('pe_dependable', @modpath1, :metadata => {
            :version => '0.0.5',
            :requirements => [
              { "name" => "PE", "version_requirement" => "3.x" },
              { "name" => "PE", "version_requirement" => "1.x" }
            ]
          })

          Puppet.expects(:warning).with(regexp_matches(/'pe_dependable' \(v0\.0\.5\) requires Puppet Enterprise 1\.x/))

          Puppet::Face[:module, :current].list_when_rendering_console(
            Puppet::Face[:module, :current].list, {:tree => true}
          )
        end
      end
    end

    context "when not running PE" do
      before(:each) do
        Puppet.stubs(:enterprise?).returns(false)
      end

      it "should NOT warn when unsatisifed PE requirements are present" do
        PuppetSpec::Modules.create('pe_dependable', @modpath1, :metadata => {
          :version => '0.0.5',
          :requirements => [{
            "name" => "PE",
            "version_requirement" => "2.x"
          }]
        })

        Puppet.expects(:warning).never

        Puppet::Face[:module, :current].list_when_rendering_console(
          Puppet::Face[:module, :current].list, {:tree => true}
        )
      end
    end
  end
end
