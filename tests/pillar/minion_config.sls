salt:
  minion:
    enabled: true
    master:
      host: config01.dc01.domain.com
    config:
      influxdb:
        host: localhost
        port: 8086
      mysqlite:
        driver: sqlite3
