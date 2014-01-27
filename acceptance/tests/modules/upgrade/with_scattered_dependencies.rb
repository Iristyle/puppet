test_name "puppet module upgrade (with scattered dependencies)"

step 'Setup'

stub_forge_on(master)
testdir = master.tmpdir('scattereddeps')
on master, "mkdir -p #{master['distmoduledir']}"
on master, "mkdir -p #{master['sitemoduledir']}"
on master, "mkdir -p #{testdir}/modules"

teardown do
  on master, "rm -rf #{master['distmoduledir']}/java"
  on master, "rm -rf #{master['distmoduledir']}/postql"
end

master_opts = {
  'main' => {
    'modulepath' => "#{testdir}/modules:#{master['distmoduledir']}:#{master['sitemoduledir']}"
  }
}

with_puppet_running_on master, master_opts, testdir do
  on master, puppet("module install pmtacceptance-stdlub --version 0.0.2 --target-dir #{testdir}/modules")
  on master, puppet("module install pmtacceptance-java --version 1.6.0 --target-dir #{master['distmoduledir']} --ignore-dependencies")
  on master, puppet("module install pmtacceptance-postql --version 0.0.1 --target-dir #{master['distmoduledir']} --ignore-dependencies")
  on master, puppet("module list") do
    assert_match /pmtacceptance-java.*1\.6\.0/, stdout, 'Could not find pmtacceptance/java'
    assert_match /pmtacceptance-postql.*0\.0\.1/, stdout, 'Could not find pmtacceptance/postql'
    assert_match /pmtacceptance-stdlub.*0\.0\.2/, stdout, 'Could not find pmtacceptance/stdlub'
  end

  step "Upgrade a module that has a more recent version published"
  on master, puppet("module upgrade pmtacceptance-postql --version 0.0.2") do
    assert_output <<-OUTPUT
      \e[mNotice: Preparing to upgrade 'pmtacceptance-postql' ...\e[0m
      \e[mNotice: Found 'pmtacceptance-postql' (\e[0;36mv0.0.1\e[m) in #{master['distmoduledir']} ...\e[0m
      \e[mNotice: Downloading from https://forgeapi.puppetlabs.com ...\e[0m
      \e[mNotice: Upgrading -- do not interrupt ...\e[0m
      #{master['distmoduledir']}
      └─┬ pmtacceptance-postql (\e[0;36mv0.0.1 -> v0.0.2\e[0m)
        ├─┬ pmtacceptance-java (\e[0;36mv1.6.0 -> v1.7.0\e[0m)
        │ └── pmtacceptance-stdlub (\e[0;36mv0.0.2 -> v1.0.0\e[0m) [#{testdir}/modules]
        └── pmtacceptance-stdlub (\e[0;36mv0.0.2 -> v1.0.0\e[0m) [#{testdir}/modules]
    OUTPUT
  end
end
