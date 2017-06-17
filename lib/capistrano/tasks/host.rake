namespace :host do

  # Basic host setup tasks

  desc 'Perform initial basic host setup'
  task setup: [:set_ssh_authorized_keys, :update_system, :set_host_name, :configure_cron, :install_docker, :enable_docker, :cleanup]

  desc 'Clean up'
  task :cleanup do
    on roles(:all) do
      sudo :yum, '-y', 'clean', 'all'
      sudo :rm, '-rf', '/etc/{.pwd.lock,group-,gshadow-,passwd-,shadow-}',
                       '/home/ec2-user/{.dbshell,.gem,.gnupg,.irb-history,.mongorc.js,.mysql_history,.node-gyp,.npm,.pki,.pry_history,.rnd,.viminfo}',
                       '/root/{.bash_history,.gem,.gnupg,.node-gyp,.npm,.pki,.rnd,.ssh,.viminfo}',
                       '/tmp/{.ICE-unix,bundler*,hsperfdata_*,motd.*,npm-*,passenger_native_support*,spring}',
                       '/var/log/{*.0,*.gz,*.old}',
                       '/var/tmp/*'
    end
  end


  desc 'Configure Cron'
  task :configure_cron do
    crontab_dir_local = fetch(:cron_crontab_dir_local, 'config/deploy')
    crontab_dir_remote = fetch(:cron_crontab_dir_remote, '/etc/cron.d')

    on roles(:all) do |host|
      config = host.properties.cron || {}
      if config[:name]
        crontab_local = "#{crontab_dir_local}/crontab.#{config[:name]}"
        crontab_remote = "#{crontab_dir_remote}/#{config[:name]}"
        tmp_file = "#{fetch(:tmp_dir)}/#{Array.new(10) { [*'0'..'9'].sample }.join}"

        upload! crontab_local, tmp_file
        sudo :cp, '-f', tmp_file, crontab_remote
        sudo :chmod, 'ugo+r', crontab_remote
        execute :rm, '-f', tmp_file
      end
    end
  end


  desc 'Install backup data volume script'
  task :install_backup_data_volume_script do
    backup_script = <<-'eos'
#!/usr/bin/env ruby
require 'aws-sdk-v1'

volume_device = ARGV[0]

ec2 = AWS::EC2.new
instance_id = Net::HTTP.get(URI.parse('http://169.254.169.254/latest/meta-data/instance-id'))
volume_id = ec2.instances[instance_id].attachments[volume_device].volume.id

backup_time = Time.now.utc
backup_days = (ENV['BACKUP_DAYS'] ? ENV['BACKUP_DAYS'].to_i : 14)
backup_tag = ENV['BACKUP_TAG'] || 'backup'

# Create new backup snapshot
new_snapshot = ec2.snapshots.create(:volume_id => volume_id)
ec2.tags.create(new_snapshot, 'Name', :value => "#{backup_tag}-#{backup_time.strftime('%Y%m%dT%H%M%S')}")
puts "Created #{new_snapshot.id}"

# Delete expired backup snapshots
snapshot_ids = ec2.snapshots.with_owner(:self).collect { |snapshot| snapshot.id if snapshot.volume_id == volume_id }.compact
snapshot_ids.each do |snapshot_id|
  snapshot = ec2.snapshots[snapshot_id]
  if (backup_time - snapshot.start_time) > backup_days*24*60*60
    snapshot.delete
    puts "Deleted #{snapshot_id}"
  end
end

exit
eos
    script_remote = 'bin/backup_data_volume'

    on roles(:all) do
      sudo :yum, '-y', 'install', 'ruby', 'ruby-devel'
      sudo :gem, 'install', 'nokogiri', '-v=1.6.6.2', '--no-document'
      sudo :gem, 'install', 'aws-sdk-v1', '-v=1.66.0', '--no-document'
      execute :mkdir, '-p', File.dirname(script_remote)
      upload! StringIO.new(backup_script), script_remote
      execute :chmod, '+x', script_remote
    end
  end


  desc 'Run command'
  task :run_command, :command do |t, args|
    on roles(:all) do
      sudo :bash, '-c', '-l', "\"#{args[:command]}\""
    end
  end


  desc 'Set host name'
  task :set_host_name do
    on roles(:all) do |host|
      host_name = host.properties.host_name || fetch(:application)
      sudo :hostname, host_name
      sudo :sed, '-i', "s/^HOSTNAME=.*/HOSTNAME=#{host_name}/g", '/etc/sysconfig/network'
    end
  end


  desc 'Set SSH authorized keys'
  task :set_ssh_authorized_keys do
    ssh_authorized_keys_file_local = fetch(:ssh_authorized_keys_file_local, './secrets/authorized_keys')
    ssh_authorized_keys_file_remote = fetch(:ssh_authorized_keys_file_remote, '.ssh/authorized_keys')

    on roles(:all) do
      upload! ssh_authorized_keys_file_local, ssh_authorized_keys_file_remote
      execute :chmod, 'go-rwx', ssh_authorized_keys_file_remote
    end
  end


  desc 'Update system'
  task :update_system do
    on roles(:all) do
      sudo :yum, '-y', 'update'
      sudo :yum, '-y', 'clean', 'all'
    end
  end




  # Docker

  desc 'Enable Docker'
  task :enable_docker do
    on roles(:docker) do
      sudo :service, 'docker', 'start'
      sudo :chkconfig, 'docker', 'on'
    end
  end


  desc 'Install Docker'
  task :install_docker do
    on roles(:docker) do
      sudo :yum, '-y', 'install', 'docker'
      sudo :bash, '-c', '"(curl -Ls --retry 3 https://github.com/docker/compose/releases/download/1.13.0/docker-compose-Linux-x86_64 > /usr/bin/docker-compose) && chmod +x /usr/bin/docker-compose"'
      sudo :bash, '-c', '"if id app ; then userdel -r app ; fi"'
      sudo :useradd, 'app', '-c', 'app', '-M', '-u', '9999'
    end
  end




  # Memcached

  desc 'Configure Memcached'
  task :configure_memcached do
    on roles(:memcached) do
      cache_size = fetch(:memcached_cache_size, 64)
      sudo :sed, '-i', "'s/^CACHESIZE=.*/CACHESIZE=\"#{cache_size}\"/'", '/etc/sysconfig/memcached'
    end
  end


  desc 'Enable Memcached'
  task :enable_memcached do
    on roles(:memcached) do
      sudo :service, 'memcached', 'start'
      sudo :chkconfig, 'memcached', 'on'
    end
  end




  # Mongo DB

  desc 'Configure Mongo DB server'
  task :configure_mongod do
    config_file_local = fetch(:mongod_config_file_local, 'config/deploy/mongod.conf')
    config_file_remote = fetch(:mongod_config_file_remote, '/etc/mongod.conf')
    tmp_file = "#{fetch(:tmp_dir)}/#{Array.new(10) { [*'0'..'9'].sample }.join}"

    on roles(:mongod) do
      upload! config_file_local, tmp_file
      sudo :cp, '-f', tmp_file, config_file_remote
      sudo :chmod, 'ugo+r', config_file_remote
      execute :rm, '-f', tmp_file

      sudo :mkdir, '-p', '/home/mongod'
      sudo :bash, '-c', "\"echo \\\"#{fetch(:mongod_data_volume_device, '/dev/xvdf')} /home/mongod ext4 defaults,noatime 0 0\\\" >> /etc/fstab\""
    end
  end


  desc 'Disable Transparent Huge Pages'
  task :disable_thp do

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

    init_script_local = StringIO.new(init_script)
    init_script_remote = '/etc/init.d/disable-thp'
    tmp_file = "#{fetch(:tmp_dir)}/#{Array.new(10) { [*'0'..'9'].sample }.join}"

    on roles(:mongod) do
      upload! init_script_local, tmp_file
      sudo :cp, '-f', tmp_file, init_script_remote
      sudo :chmod, 'ugo+rx', init_script_remote
      execute :rm, '-f', tmp_file

      sudo :service, 'disable-thp', 'start'
      sudo :chkconfig, 'disable-thp', 'on'
    end
  end


  desc 'Enable Mongo DB server'
  task :enable_mongod do
    on roles(:mongod) do
      sudo :chkconfig, 'mongod', 'on'
    end
  end




  # MySQL

  desc 'Configure MySQL DB server'
  task :configure_mysql do
    config_file_local = fetch(:mysql_config_file_local, 'config/deploy/my.cnf')
    config_file_remote = fetch(:mysql_config_file_remote, '/etc/my.cnf')
    tmp_file = "#{fetch(:tmp_dir)}/#{Array.new(10) { [*'0'..'9'].sample }.join}"

    on roles(:mysql) do
      upload! config_file_local, tmp_file
      sudo :cp, '-f', tmp_file, config_file_remote
      sudo :chmod, 'ugo+r', config_file_remote
      execute :rm, '-f', tmp_file

      sudo :mkdir, '-p', '/home/mysql'
      sudo :bash, '-c', "\"echo \\\"#{fetch(:mysql_data_volume_device, '/dev/xvdf')} /home/mysql ext4 defaults,noatime 0 0\\\" >> /etc/fstab\""
    end
  end


  desc 'Enable MySQL DB server'
  task :enable_mysql do
    on roles(:mysql) do
      sudo :chkconfig, 'mysqld', 'on'
    end
  end


  desc 'Install MySQL DB server'
  task :install_mysql do
    on roles(:mysql) do
      sudo :bash, '-c', '"for PKG in mysql-config mysql55 mysql55-libs ; do if (yum list installed \${PKG}) ; then yum -y erase \${PKG} ; fi ; done"'
      sudo :yum, '-y', 'install', 'mysql56-server'
    end
  end




  # Redis

  desc 'Configure Redis'
  task :configure_redis do
    config_file_local = fetch(:redis_config_file_local, 'config/deploy/redis.conf')
    config_file_remote = fetch(:redis_config_file_remote, '/etc/redis.conf')
    tmp_file = "#{fetch(:tmp_dir)}/#{Array.new(10) { [*'0'..'9'].sample }.join}"

    on roles(:redis) do
      upload! config_file_local, tmp_file
      sudo :cp, '-f', tmp_file, config_file_remote
      sudo :chmod, 'ugo+r', config_file_remote
      execute :rm, '-f', tmp_file
    end
  end


  desc 'Enable Redis'
  task :enable_redis do
    on roles(:redis) do
      sudo :service, 'redis', 'start'
      sudo :chkconfig, 'redis', 'on'
    end
  end
end
