test_name "puppet module upgrade (where newer version does not support pe version on SUT)"
require 'puppet/acceptance/module_utils'
extend Puppet::Acceptance::ModuleUtils

module_author = "pmtacceptance"
module_name   = "pe_version"
module_dependencies = []

orig_installed_modules = get_installed_modules_for_hosts hosts

stub_forge_on(master)
distmoduledir = on(master, puppet("agent", "--configprint", "confdir")).stdout.chomp + "/modules"

pe_major = get_pe_version(master)[:major]
module_version = "#{pe_major}.5.0"
module_upgrade_version = "#{pe_major}.7.0"

teardown do
  rm_installed_modules_from_hosts orig_installed_modules, (get_installed_modules_for_hosts hosts)
end


step "install module" do
  on(master, puppet("module install #{module_author}-#{module_name} --version #{module_version}"))
end

step "upgrade module" do
  on(master, puppet("module upgrade #{module_author}-#{module_name} --version #{module_upgrade_version}"), :acceptable_exit_codes => [1])
  assert_module_installed_on_disk(master, distmoduledir, module_name, module_version)
end
