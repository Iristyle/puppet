test_name "puppet module install for specified supported x.x.x pe version where dependency is not supported"
require 'puppet/acceptance/module_utils'
extend Puppet::Acceptance::ModuleUtils

module_author = "pmtacceptance"
module_name   = "depends_on_pe_version"
module_dependencies = ["pe_version"]

orig_installed_modules = get_installed_modules_for_hosts hosts

stub_forge_on(master)
distmoduledir = on(master, puppet("agent", "--configprint", "confdir")).stdout.chomp + "/modules"

teardown do
  rm_installed_modules_from_hosts orig_installed_modules, (get_installed_modules_for_hosts hosts)
end

step "install module with unsupported dependency" do
  on(master, puppet("module install #{module_author}-#{module_name} --version 1.0.0"), :acceptable_exit_codes => [1])
  assert_module_not_installed_on_disk(master, distmoduledir, module_name)
  module_dependencies.each do |dependency|
    assert_module_not_installed_on_disk(master, distmoduledir, dependency)
  end
end
