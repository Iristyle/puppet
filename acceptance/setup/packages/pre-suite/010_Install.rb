require 'puppet/acceptance/install_utils'

extend Puppet::Acceptance::InstallUtils

test_name "Install Packages"

step "Install repositories on target machines..." do

  sha = ENV['SHA']
  repo_configs_dir = 'repo-configs'

  hosts.each do |host|
    install_repos_on(host, 'puppet', sha, repo_configs_dir)
  end
end


MASTER_PACKAGES = {
  :redhat => [
    'puppet-server',
  ],
  :debian => [
    'puppetmaster-passenger',
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
    'puppet',
  ],
  :debian => [
    'puppet',
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
    # needs to change to puppet-agent when MSI building pipeline is correct
    # base_url = "http://builds.puppetlabs.lan/puppet-agent/#{ENV['SHA']}/artifacts/windows"
    # base_url = "http://builds.puppetlabs.lan/puppet/#{ENV['SHA']}/artifacts/windows"
    base_url = ENV['MSI_BASE_URL'] || "http://builds.puppetlabs.lan/puppet/#{ENV['SHA']}/artifacts/windows"
    filename = ENV['MSI_FILENAME'] || "puppet-agent-#{ENV['VERSION']}-#{arch}.msi"
    # TESTING with http://int-resources/aio/puppet-agent-1.0.0-aio-ga354e25-x64.msi
    # MSI_BASE_URL = http://int-resources/aio
    # VERSION = 1.0.0-aio-ga354e25

    install_puppet_from_msi(agent, :url => "#{base_url}/#{filename}")
  end
end

configure_gem_mirror(hosts)

