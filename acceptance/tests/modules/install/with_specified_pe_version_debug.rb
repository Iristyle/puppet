test_name "puppet module install specifying version using debug"
require 'puppet/acceptance/module_utils'
extend Puppet::Acceptance::ModuleUtils

module_author = "pmtacceptance"
module_name   = "pe_version"
module_version = "#{get_pe_version(master)[:major]}.0.0"
module_dependencies = []

orig_installed_modules = get_installed_modules_for_hosts hosts

stub_forge_on(master)
distmoduledir = on(master, puppet("agent", "--configprint", "confdir")).stdout.chomp + "/modules"

teardown do
    rm_installed_modules_from_hosts orig_installed_modules, (get_installed_modules_for_hosts hosts)
end

step "install module" do
  on(master, puppet("module install #{module_author}-#{module_name} --version #{module_version} --debug")) do |res|
    assert_match(/#{module_name} compatible with PE/, res.stdout)
    assert_match(/Skipping/, res.stdout)
    assert_module_installed_on_disk(master, distmoduledir, module_name, module_version)
  end
end
