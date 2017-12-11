

describe file('/etc/salt/minion.d/minion.conf') do
    it('should exist')
    its('content') { should match /influxdb:/ }
    its('content') { should match /^  port: 8086/ }
    its('content') { should match /mysqlite:/ }
end

