require 'puppet/acceptance/install_utils'

extend Puppet::Acceptance::InstallUtils

test_name "Install Packages"

step "Install repositories on target machines..." do

  sha = ENV['SHA']
  repo_configs_dir = 'repo-configs'

  hosts.each do |host|
    if host == master
      install_repos_on(host, 'puppet-agent', '0.3.1', repo_configs_dir)
    else
      install_repos_on(host, 'puppet-agent', sha, repo_configs_dir)
    end
  end

  install_repos_on(master, 'puppetserver', 'nightly', repo_configs_dir)
end


MASTER_PACKAGES = {
  :redhat => [
    'puppetserver',
  ],
  :debian => [
    'puppetserver',
  ],
#  :solaris => [
#    'puppet-server',
#  ],
#  :windows => [
#    'puppet-server',
#  ],
}

AGENT_PACKAGES = {
  :redhat => [
    'puppet-agent',
  ],
  :debian => [
    'puppet-agent',
  ],
#  :solaris => [
#    'puppet',
#  ],
#  :windows => [
#    'puppet',
#  ],
}

install_packages_on(master, MASTER_PACKAGES)
install_packages_on(agents, AGENT_PACKAGES)

agents.each do |agent|
  if agent['platform'] =~ /windows/
    arch = agent[:ruby_arch] || 'x86'
    base_url = ENV['MSI_BASE_URL'] || "http://builds.puppetlabs.lan/puppet-agent/#{ENV['SHA']}/artifacts/windows"
    filename = ENV['MSI_FILENAME'] || "puppet-agent-#{ENV['VERSION']}-#{arch}.msi"
    # TESTING with http://int-resources.corp.puppetlabs.net/aio/puppet-agent-1.0.0-aio-ga354e25-x64.msi
    # bundle exec rake ci:test:aio CONFIG=config/nodes/win2012r2-rubyx64.yaml SHA=8642ba76b6166b2bb788a9a6f7e62ee46db2234f VERSION=1.0.0-aio-ga354e25 MSI_BASE_URL=http://int-resources.corp.puppetlabs.net/aio
    # MSI_BASE_URL = http://int-resources.corp.puppetlabs.net/aio
    # VERSION = 1.0.0-aio-ga354e25

    install_puppet_from_msi(agent, :url => "#{base_url}/#{filename}")
  end
end

configure_gem_mirror(hosts)
