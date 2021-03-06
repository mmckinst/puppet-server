## Tests that PuppetDB can be integrated with Puppet Server in a simple
## monolithic install (i.e. PuppetDB on same node as Puppet Server).
##
## In this context 'integrated' just means that Puppet Server is able to
## communicate over HTTP/S with PuppetDB to send it information, such as
## agent run reports.
##
## This test validates communication is successful by querying the PuppetDB HTTP
## API and asserting the agent's report timestamp is not null. This means that
## PuppetDB successfully received the agent's report sent from Puppet Server.
## We can just run the agent that's on the master for this.

confine :to, {:platform => puppetdb_supported_platforms}, master

require 'json'

test_name 'PuppetDB integration'

step 'Install PuppetDB module' do
  on(master, puppet('module install puppetlabs-puppetdb'))
end

step 'Configure PuppetDB via site.pp' do
  sitepp = '/etc/puppetlabs/code/environments/production/manifests/site.pp'
  create_remote_file(master, sitepp, <<SITEPP)
node default {
  class { 'puppetdb':
    manage_firewall => false,
  }
  class { 'puppetdb::master::config':
    puppet_service_name     => #{options['puppetservice']},
    manage_report_processor => true,
    enable_reports          => true,
  }
}
SITEPP
  on(master, "chmod 644 #{sitepp}")
  teardown do
    on(master, "rm -f #{sitepp}")
  end
end

step 'Install PuppetDB with agent run' do
  with_puppet_running_on(master, {}) do
    on(master, puppet_agent("--test --server #{master}"), :acceptable_exit_codes => [0,2])
  end
end

step 'Validate server sent agent report to PuppetDB' do
  fqdn = on(master, '/opt/puppetlabs/bin/facter fqdn').stdout.chomp
  query = "curl http://localhost:8080/pdb/query/v4/nodes/#{fqdn}"
  response = JSON.parse(on(master, query).stdout.chomp)
  assert(response['report_timestamp'] != nil)
end
