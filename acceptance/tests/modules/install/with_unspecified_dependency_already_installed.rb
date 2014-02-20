test_name "puppet module install for specified supported x.x.x pe version where dependency is already installed"
require 'puppet/acceptance/module_utils'
extend Puppet::Acceptance::ModuleUtils

module_author = "pmtacceptance"
module_name   = "depends_on_pe_version"
module_version = "1.0.0"
module_dependencies = [ "pe_version" ]

orig_installed_modules = get_installed_modules_for_hosts hosts

stub_forge_on(master)
distmoduledir = on(master, puppet("agent", "--configprint", "confdir")).stdout.chomp + "/modules"

teardown do
  rm_installed_modules_from_hosts orig_installed_modules, (get_installed_modules_for_hosts hosts)
end

step 'install dependency with unspecified pe support' do
  # write dependency to disk pe_version 1.6.0
  # manually write metadata.json with no pe requirement
  apply_manifest_on master, <<-PP
file {
  [
    '#{distmoduledir}/#{module_dependencies[0]}',
  ]: ensure => directory;
  '#{distmoduledir}/#{module_dependencies[0]}/metadata.json':
    content => '{
      "name": "#{module_author}/#{module_dependencies[0]}",
      "version": "1.6.0",
      "source": "",
      "author": "#{module_author}",
      "license": "MIT",
      "dependencies": []
    }';
}
PP
end

step "install supported pe_version that depends on dependency" do
  on(master, puppet("module install #{module_author}-#{module_name} --version #{module_version}")) do
    assert_module_installed_ui(stdout, module_author, module_name, module_version)
  end
end
