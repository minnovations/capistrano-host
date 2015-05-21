namespace :host do
  desc 'Perform initial basic host setup'
  task setup: [:set_ssh_authorized_keys, :set_host_name, :update_system, :cleanup]

  desc 'Clean up'
  task :cleanup do
    on roles(:all) do
      sudo :yum, '-y', 'clean', 'all'
      sudo :rm, '-rf', '/etc/{.pwd.lock,group-,gshadow-,passwd-,shadow-}',
                       '/home/ec2-user/{.dbshell,.gem,.gnupg,.irb-history,.mongorc.js,.mysql_history,.node-gyp,.npm,.pki,.pry_history,.rnd,.viminfo}',
                       '/root/{.bash_history,.gem,.gnupg,.node-gyp,.npm,.pki,.rnd,.ssh,.viminfo}',
                       '/tmp/{.ICE-unix,bundler*,motd.*,passenger_native_support*,spring}',
                       '/var/log/{*.0,*.gz,*.old}',
                       '/var/tmp/*'
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

  desc 'Set Memcached'
  task :set_memcached do
    on roles(:memcached) do
      sudo :service, 'memcached', 'start'
      sudo :chkconfig, 'memcached', 'on'
    end
  end

  desc 'Set Redis'
  task :set_redis do
    on roles(:redis) do
      sudo :service, 'redis', 'start'
      sudo :chkconfig, 'redis', 'on'
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
end
