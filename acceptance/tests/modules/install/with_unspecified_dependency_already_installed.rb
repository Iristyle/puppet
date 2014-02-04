test_name "puppet module install for specified supported x.x.x pe version where dependency is already installed"
require 'puppet/acceptance/module_utils'
extend Puppet::Acceptance::ModuleUtils

module_author = "pmtacceptance"
module_name   = "depends_on_pe_version"
module_dependencies = []

orig_installed_modules = get_installed_modules_for_hosts hosts

stub_forge_on(master)
distmoduledir = on(master, puppet("agent", "--configprint", "confdir")).stdout.chomp + "/modules"

teardown do
  rm_installed_modules_from_hosts orig_installed_modules, (get_installed_modules_for_hosts hosts)
end

step 'setup' do
  # write dependency to disk pe_version 1.6.0
  # manually write metadata.json with no pe requirement
  apply_manifest_on master, <<-PP
file {
  [
    '#{distmoduledir}',
  ]: ensure => directory;
  '#{distmoduledir}/#{module_name}/metadata.json':
    content => '{
      "name": "#{module_author}/#{module_name}",
      "version": "1.6.0",
      "source": "",
      "author": "#{module_author}",
      "license": "MIT",
      "dependencies": []
    }';
}
PP
end

step "install incompatible supported pe_version" do
  on(master, puppet("module install #{module_author}-#{module_name} --version 1.0.1")) do
    assert_module_installed_ui(stdout, module_author, module_name, module_version)
  end
end
