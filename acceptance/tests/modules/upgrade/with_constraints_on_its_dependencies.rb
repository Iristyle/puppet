test_name "puppet module upgrade (with constraints on its dependencies)"

step 'Setup'

stub_forge_on(master)

teardown do
  on master, "rm -rf #{master['distmoduledir']}/unicorns"
  on master, "rm -rf #{master['distmoduledir']}/java"
  on master, "rm -rf #{master['distmoduledir']}/stdlub"
end

apply_manifest_on master, <<-PP
  file {
    [
      '#{master['distmoduledir']}/unicorns',
    ]: ensure => directory;
    '#{master['distmoduledir']}/unicorns/metadata.json':
      content => '{
        "name": "notpmtacceptance/unicorns",
        "version": "0.0.3",
        "source": "",
        "author": "notpmtacceptance",
        "license": "MIT",
        "dependencies": [
          { "name": "pmtacceptance/stdlub", "version_requirement": "0.0.2" }
        ]
      }';
  }
PP
on master, puppet("module install pmtacceptance-stdlub --version 0.0.2")
on master, puppet("module install pmtacceptance-java --version 1.6.0")
on master, puppet("module list --modulepath #{master['distmoduledir']}") do
  assert_output <<-OUTPUT
    #{master['distmoduledir']}
    ├── notpmtacceptance-unicorns (\e[0;36mv0.0.3\e[0m)
    ├── pmtacceptance-java (\e[0;36mv1.6.0\e[0m)
    └── pmtacceptance-stdlub (\e[0;36mv0.0.2\e[0m)
  OUTPUT
end

# FIXME PF-357 (maybe)
step "Try to upgrade a module with constraints on its dependencies that cannot be met"
on master, puppet("module upgrade pmtacceptance-java --version 1.7.1"), :acceptable_exit_codes => [1] do
  assert_match(/No version.* can satisfy all dependencies/, stderr,
        "Unsatisfiable dependency was not displayed")
end

step "Relax constraints"
on master, puppet("module uninstall notpmtacceptance-unicorns")
on master, puppet("module list --modulepath #{master['distmoduledir']}") do
  assert_output <<-OUTPUT
    #{master['distmoduledir']}
    ├── pmtacceptance-java (\e[0;36mv1.6.0\e[0m)
    └── pmtacceptance-stdlub (\e[0;36mv0.0.2\e[0m)
  OUTPUT
end

step "Upgrade a single module, ignoring its dependencies"
on master, puppet("module upgrade pmtacceptance-java --version 1.7.0 --ignore-dependencies") do
  assert_output <<-OUTPUT
    \e[mNotice: Preparing to upgrade 'pmtacceptance-java' ...\e[0m
    \e[mNotice: Found 'pmtacceptance-java' (\e[0;36mv1.6.0\e[m) in #{master['distmoduledir']} ...\e[0m
    \e[mNotice: Downloading from https://forgeapi.puppetlabs.com ...\e[0m
    \e[mNotice: Upgrading -- do not interrupt ...\e[0m
    #{master['distmoduledir']}
    └── pmtacceptance-java (\e[0;36mv1.6.0 -> v1.7.0\e[0m)
  OUTPUT
end

# FIXME we no longer will upgrade across major versions (stdlub dependency)
#step "Upgrade a module with constraints on its dependencies that can be met"
#on master, puppet("module upgrade pmtacceptance-java") do
#  assert_output <<-OUTPUT
#    \e[mNotice: Preparing to upgrade 'pmtacceptance-java' ...\e[0m
#    \e[mNotice: Found 'pmtacceptance-java' (\e[0;36mv1.7.0\e[m) in #{master['distmoduledir']} ...\e[0m
#    \e[mNotice: Downloading from https://forgeapi.puppetlabs.com ...\e[0m
#    \e[mNotice: Upgrading -- do not interrupt ...\e[0m
#    #{master['distmoduledir']}
#    └─┬ pmtacceptance-java (\e[0;36mv1.7.0 -> v1.7.1\e[0m)
#      └── pmtacceptance-stdlub (\e[0;36mv0.0.2 -> v1.0.0\e[0m)
#  OUTPUT
#end
