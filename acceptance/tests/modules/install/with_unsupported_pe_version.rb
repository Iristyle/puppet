test_name "puppet module install for specified unsupported x.x.x pe version"
require 'puppet/acceptance/module_utils'
extend Puppet::Acceptance::ModuleUtils

distmoduledir = on(master, puppet("agent", "--configprint", "confdir")).stdout.chomp + "/modules"

module_author = "pmtacceptance"
module_name   = "pe_version"
module_dependencies = []

orig_installed_modules = get_installed_modules_for_hosts hosts

stub_forge_on(master)

teardown do
  rm_installed_modules_from_hosts orig_installed_modules, (get_installed_modules_for_hosts hosts)
end

step "install incompatible supported pe_version" do
  on(master, puppet("module install #{module_author}-#{module_name} --version 1.0.0"), :acceptable_exit_codes => [1])
  assert_module_not_installed_on_disk(master, distmoduledir, module_name)
end
