test_name "puppet module upgrade (where newer version has support for pe version on SUT, but dependency does not)"
require 'puppet/acceptance/module_utils'
extend Puppet::Acceptance::ModuleUtils

module_author = "pmtacceptance"
module_name   = "depends_on_pe_version"
module_dependencies = [ "pe_version" ]

orig_installed_modules = get_installed_modules_for_hosts hosts

stub_forge_on(master)
distmoduledir = on(master, puppet("agent", "--configprint", "confdir")).stdout.chomp + "/modules"

pe_major = get_pe_version(master)[:major]
module_version = "#{pe_major}.0.0"
module_upgrade_version = "#{pe_major}.7.0"

teardown do
  rm_installed_modules_from_hosts orig_installed_modules, (get_installed_modules_for_hosts hosts)
end


step "install module" do
  dependencies = '[ { "name": "#{module_author}/#{module_dependencies[0]}", "version_requirement": "3.x" } ]'
  install_module_to_disk(master, distmoduledir, module_author, module_name, module_version, dependencies)

  requirements = '[{ "name": "pe", "version_requirement": ">= 3.0.0" }]'
  install_module_to_disk(master, distmoduledir, module_author, module_name, "#{pe_major}.5.0", nil, requirements)
end

step "upgrade module" do
  on(master, puppet("module upgrade #{module_author}-#{module_name} --version #{module_upgrade_version}"), :acceptable_exit_codes => [1])
  assert_module_installed_on_disk(master, distmoduledir, module_name, module_version)
  module_dependencies.each do |dependency|
   assert_module_installed_on_disk(master, distmoduledir, dependency, module_version)
  end
end
