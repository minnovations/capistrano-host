namespace :host do
  # Basic host setup tasks
  desc 'Perform initial basic host setup'
  task setup: [:set_ssh_authorized_keys, :update_system, :set_host_name, :configure_cron, :cleanup]

  desc 'Clean up'
  task :cleanup do
    on roles(:all) do
      sudo :yum, '-y', 'clean', 'all'
      sudo :rm, '-rf', '/etc/{.pwd.lock,group-,gshadow-,passwd-,shadow-}',
                       '/home/ec2-user/{.dbshell,.gem,.gnupg,.irb-history,.mongorc.js,.mysql_history,.node-gyp,.npm,.pki,.pry_history,.rnd,.viminfo}',
                       '/root/{.bash_history,.gem,.gnupg,.node-gyp,.npm,.pki,.rnd,.ssh,.viminfo}',
                       '/tmp/{.ICE-unix,bundler*,hsperfdata_*,motd.*,passenger_native_support*,spring}',
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
      sudo :bash, '-c', '\'echo "/dev/xvdf /home/mongod ext4 defaults,noatime 0 0" >> /etc/fstab\''
    end
  end

  desc 'Enable Mongo DB server'
  task :enable_mongod do
    on roles(:mongod) do
      sudo :service, 'mongod', 'start'
      sudo :chkconfig, 'mongod', 'on'
    end
  end
end
