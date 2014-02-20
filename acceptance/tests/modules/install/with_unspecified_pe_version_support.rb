test_name "puppet module install for specified module version where supported pe version is unspecified"
require 'puppet/acceptance/module_utils'
extend Puppet::Acceptance::ModuleUtils

module_author = "pmtacceptance"
module_name   = "pe_version"
module_dependencies = []

orig_installed_modules = get_installed_modules_for_hosts hosts

stub_forge_on(master)
distmoduledir = on(master, puppet("agent", "--configprint", "confdir")).stdout.chomp + "/modules"

# modules on test forge of version x.6.0 will not specify a supported pe version
module_version = "#{get_pe_version(master)[:major]}.6.0"

teardown do
  rm_installed_modules_from_hosts orig_installed_modules, (get_installed_modules_for_hosts hosts)
end

step "install module whose supported pe_version is unspecified" do
  on(master, puppet("module install #{module_author}-#{module_name} --version #{module_version}"), :acceptable_exit_codes => [1])
  assert_module_not_installed_on_disk(master, distmoduledir, module_name)
end
