test_name "puppet module install for unspecified version, get latest supported"
require 'puppet/acceptance/module_utils'
extend Puppet::Acceptance::ModuleUtils

module_author = "pmtacceptance"
module_name   = "pe_version"
module_dependencies = []

orig_installed_modules = get_installed_modules_for_hosts hosts

stub_forge_on(master)
distmoduledir = on(master, puppet("agent", "--configprint", "confdir")).stdout.chomp + "/modules"

# the data is set up so that x.5.0 for a given module is the latest version
# that can be installed.
module_version = "#{get_pe_version(master)[:major]}.5.0"

teardown do
  rm_installed_modules_from_hosts orig_installed_modules, (get_installed_modules_for_hosts hosts)
end

step "install compatible supported pe_version" do
  on(master, puppet("module install #{module_author}-#{module_name}")) do
    assert_module_installed_ui(stdout, module_author, module_name, module_version)
  end
  # FIXME: add version assertion to _on_disk helper
  assert_module_installed_on_disk(master, distmoduledir, module_name)
end
