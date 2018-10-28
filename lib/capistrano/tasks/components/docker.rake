namespace :host do

  desc 'Setup Docker'
  task setup_docker: [:docker_install, :docker_configure, :docker_enable]


  task :docker_configure do
    on roles(:all) do
      sudo :usermod, '-a', '-G', 'docker', 'ec2-user'
      sudo :sed, '-i', "'s/^OPTIONS=.*/OPTIONS=\"--default-ulimit nofile=4096:8192 --log-opt max-size=50m --log-opt max-file=5\"/'", '/etc/sysconfig/docker'
    end
  end


  task :docker_enable do
    on roles(:all) do
      sudo :service, 'docker', 'start'
      sudo :chkconfig, 'docker', 'on'
    end
  end


  task :docker_install do
    on roles(:all) do
      sudo :yum, '-y', 'install', 'docker'
      sudo :curl, '-Ls', '-o', '/usr/bin/docker-compose', '--retry', '3', 'https://github.com/docker/compose/releases/download/1.15.0/docker-compose-Linux-x86_64'
      sudo :chmod, '+x', '/usr/bin/docker-compose'
    end
  end

end
