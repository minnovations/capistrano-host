namespace :host do

  desc 'Setup Mongo'
  task setup_mongo: [:mongo_install, :mongo_configure, :mongo_disable_thp, :mongo_enable]


  task :mongo_configure do
    on roles(:all) do
      upload_file('config/mongod.conf', '/etc/mongod.conf')
      sudo :mkdir, '-p', '/home/mongod'

      data_volume_device = fetch(:host_mongo_data_volume_device) || '/dev/xvdf'
      sudo :sed, '-i', "'/^#{data_volume_device.gsub('/', '\/')} /d'", '/etc/fstab'
      sudo :bash, '-c', "\"echo \\\"#{data_volume_device} /home/mongod ext4 defaults,noatime 0 0\\\" >> /etc/fstab\""
    end
  end


  task :mongo_disable_thp do
    init_script = <<-eos
#!/bin/sh
### BEGIN INIT INFO
# Provides:          disable-transparent-hugepages
# Required-Start:    $local_fs
# Required-Stop:
# X-Start-Before:    mongod mongodb-mms-automation-agent
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: Disable Linux transparent huge pages
# Description:       Disable Linux transparent huge pages, to improve
#                    database performance.
### END INIT INFO

case $1 in
  start)
    if [ -d /sys/kernel/mm/transparent_hugepage ]; then
      thp_path=/sys/kernel/mm/transparent_hugepage
    elif [ -d /sys/kernel/mm/redhat_transparent_hugepage ]; then
      thp_path=/sys/kernel/mm/redhat_transparent_hugepage
    else
      return 0
    fi

    echo 'never' > ${thp_path}/enabled
    echo 'never' > ${thp_path}/defrag

    unset thp_path
    ;;
esac
eos

    on roles(:all) do
      upload_file(StringIO.new(init_script), '/etc/init.d/disable-thp', mod: 'ugo+rx')
      sudo :service, 'disable-thp', 'start'
      sudo :chkconfig, 'disable-thp', 'on'
    end
  end


  task :mongo_enable do
    on roles(:all) do
      sudo :chkconfig, 'mongod', 'on'
    end
  end


  task :mongo_install do
    repo_info = <<-eos
[mongodb-org-3.2]
name=MongoDB Repository
baseurl=https://repo.mongodb.org/yum/amazon/2013.03/mongodb-org/3.2/x86_64/
gpgcheck=1
enabled=1
gpgkey=https://www.mongodb.org/static/pgp/server-3.2.asc
eos

    on roles(:all) do
      upload_file(StringIO.new(repo_info), '/etc/yum.repos.d/mongodb.repo')
      sudo :yum, '-y', 'install', 'mongodb-org'
    end
  end

end
