test_name "puppet module install (with specified supported x.x.x pe version)"
require 'puppet/acceptance/module_utils'
extend Puppet::Acceptance::ModuleUtils

module_author = "pmtacceptance"
module_name   = "pe_version"
module_dependencies = []

orig_installed_modules = get_installed_modules_for_hosts hosts

stub_forge_on(master)
distmoduledir = on(master, puppet("agent", "--configprint", "confdir")).stdout.chomp + "/modules"

module_version = "#{get_pe_version(master)[:major]}.0.0"

teardown do
  rm_installed_modules_from_hosts orig_installed_modules, (get_installed_modules_for_hosts hosts)
end

step "install module specified as supported by pe version" do
  on(master, puppet("module install #{module_author}-#{module_name} --version #{module_version}")) do
    assert_module_installed_ui(stdout, module_author, module_name)
  end
  assert_module_installed_on_disk(master, distmoduledir, module_name)
end
