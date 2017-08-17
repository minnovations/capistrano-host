namespace :host do

  desc 'Setup MySQL'
  task setup_mysql: [:mysql_install, :mysql_configure, :mysql_enable]


  task :mysql_configure do
    on roles(:all) do
      upload_file("#{config_dir}/my.cnf", '/etc/my.cnf')
      sudo :mkdir, '-p', '/home/mysql'

      data_volume_device = fetch(:host_mysql_data_volume_device) || '/dev/xvdf'
      sudo :sed, '-i', "'/^#{data_volume_device.gsub('/', '\/')} /d'", '/etc/fstab'
      sudo :bash, '-c', "\"echo \\\"#{data_volume_device} /home/mysql ext4 defaults,noatime 0 0\\\" >> /etc/fstab\""
    end
  end


  task :mysql_enable do
    on roles(:all) do
      sudo :chkconfig, 'mysqld', 'on'
    end
  end


  task :mysql_install do
    on roles(:all) do
      sudo :bash, '-c', '"for PKG in mysql-config mysql55 mysql55-libs ; do if (yum list installed \${PKG}) ; then yum -y erase \${PKG} ; fi ; done"'
      sudo :yum, '-y', 'install', 'mysql56-server'
    end
  end

end
