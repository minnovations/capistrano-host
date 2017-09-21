namespace :host do

  desc 'Setup Redis'
  task setup_redis: [:redis_install, :redis_configure, :redis_enable]


  task :redis_configure do
    on roles(:all) do
      upload_file("#{config_dir}/redis.conf", '/etc/redis.conf')
      sudo :sed, '-i', "'/^vm.overcommit_memory/d'", '/etc/sysctl.conf'
      sudo :bash, '-c', "\"echo \\\"vm.overcommit_memory = 1\\\" >> /etc/sysctl.conf\""
      sudo :sysctl, '-p'
    end
  end


  task :redis_enable do
    on roles(:all) do
      sudo :service, 'redis', 'start'
      sudo :chkconfig, 'redis', 'on'
    end
  end


  task :redis_install do
    on roles(:all) do
      sudo :yum, '-y', 'install', 'https://dl.fedoraproject.org/pub/archive/epel/5/x86_64/redis-2.4.10-1.el5.x86_64.rpm'
    end
  end

end
