namespace :host do

  desc 'Setup Memcached'
  task setup_memcached: [:memcached_install, :memcached_configure, :memcached_enable]


  task :memcached_configure do
    on roles(:all) do
      cache_size = fetch(:host_memcached_cache_size, 64)
      sudo :sed, '-i', "'s/^CACHESIZE=.*/CACHESIZE=\"#{cache_size}\"/'", '/etc/sysconfig/memcached'
    end
  end


  task :memcached_enable do
    on roles(:all) do
      sudo :service, 'memcached', 'start'
      sudo :chkconfig, 'memcached', 'on'
    end
  end


  task :memcached_install do
    on roles(:all) do
      sudo :yum, '-y', 'install', 'memcached'
    end
  end

end
