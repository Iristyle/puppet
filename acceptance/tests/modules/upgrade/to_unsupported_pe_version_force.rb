test_name "puppet module upgrade (where newer version does not support pe version on SUT, but force is used)"
require 'puppet/acceptance/module_utils'
extend Puppet::Acceptance::ModuleUtils

module_author = "pmtacceptance"
module_name   = "pe_version"
module_dependencies = []

orig_installed_modules = get_installed_modules_for_hosts hosts

stub_forge_on(master)
distmoduledir = on(master, puppet("agent", "--configprint", "confdir")).stdout.chomp + "/modules"

module_version = "#{get_pe_version(master)[:major]}.0.0"
module_upgrade_version = "#{get_pe_version(master)[:major]}.5.0"

teardown do
  rm_installed_modules_from_hosts orig_installed_modules, (get_installed_modules_for_hosts hosts)
end


step "install module" do
  on(master, puppet("module install #{module_author}-#{module_name} --version #{module_version}"))
end

step "upgrade module" do
  on(master, puppet("module upgrade #{module_author}-#{module_name} --version #{module_upgrade_version} --force")) do
    assert_module_installed_ui(master, distmoduledir, module_name, module_upgrade_version)
  end
  assert_module_installed_on_disk(master, distmoduledir, module_name, module_upgrade_version)
end
