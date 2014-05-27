test_name "puppet module list (where installed version has support for pe version on SUT)"
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


step "install module" do
  on(master, puppet("module install #{module_author}-#{module_name} --version #{module_version}"))
end

step "list module" do
  on(master, puppet("module list")) do |res|
    assert_match(/#{module_author}-#{module_name}/, res.stdout)
    assert_equal('', res.stderr)
  end
end
