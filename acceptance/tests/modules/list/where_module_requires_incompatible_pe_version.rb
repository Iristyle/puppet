test_name "puppet module list (where module requires incompatible pe version)"
require 'puppet/acceptance/module_utils'
extend Puppet::Acceptance::ModuleUtils

module_author = "pmtacceptance"
module_name   = "pe_version"
module_dependencies = [ ]

orig_installed_modules = get_installed_modules_for_hosts hosts

stub_forge_on(master)
distmoduledir = on(master, puppet("agent", "--configprint", "confdir")).stdout.chomp + "/modules"

module_version = "1.0.0"

teardown do
  rm_installed_modules_from_hosts orig_installed_modules, (get_installed_modules_for_hosts hosts)
end


step "install module" do
  # FIXME: write helper to lay down #{moduel_name}/metadata.json instead of
  # using `module install` to put the module on disk for tests that have no
  # direct dependency on `module install` functionality.
  on(master, puppet("module install #{module_author}-#{module_name} --version #{module_version}"))
end

step "list module" do
  on(master, puppet("module list")) do |res|
    assert_match(/#{module_author}-#{module_name}/, res.stdout)
    assert_match(/[wW]arn/, res.stdout)
    assert_match(/requires Puppet Enterprise/, res.stdout)
  end
end
