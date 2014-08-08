# This is a workaround for PDB-707 -kbarber
test_name "Curl PuppetDB after presumed pe-postgresql restart" do
  puppetdb = hosts.detect { |h| h['roles'].include?('database') }
  on(puppetdb, "curl 'http://localhost:8080/v3/nodes'")
end
