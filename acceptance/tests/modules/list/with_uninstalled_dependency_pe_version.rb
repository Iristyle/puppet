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
  apply_manifest_on master, <<-PP
file {
  [
    '#{distmoduledir}/#{module_name}
  ]: ensure => directory,
     recurse => true,
     purge => true,
     force => true;
  '#{distmoduledir}/#{module_name}/metadata.json':
    content => '{
      "name": "pmtacceptance-pe_version",
      "version": "3.0.0",
      "source": "UNKNOWN",
      "author": "pmtacceptance",
      "license": "Apache License, Version 2.0",
      "summary": "UNKNOWN",
      "description": "UNKNOWN",
      "project_page": "UNKNOWN",
      "dependencies": [

      ],
      "types": [

      ],
      "requirements": [
        {
          "name": "pe",
          "version_requirement": "1.x"
        }
      ],
    }';
}
PP
end

step "list module" do
  on(master, puppet("module list")) do |res|
    assert_match(/#{module_author}-#{module_name}/, res.stdout)
    assert_match(/[wW]arn/, res.stdout)
    assert_match(/requires Puppet Enterprise/, res.stdout)
  end
end
