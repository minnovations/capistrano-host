namespace :host do

  # Helper Methods

  def config_dir
    "config/#{fetch(:stage)}"
  end


  def upload_file(file, dest_path, options={})
    mod = options[:mod] || 'u+rw,go+r'
    tmp_file = "#{fetch(:tmp_dir)}/#{Array.new(8) { [*'0'..'9'].sample }.join}"

    upload! file, tmp_file
    sudo :cp, '-f', tmp_file, dest_path
    sudo :chmod, mod, dest_path
    execute :rm, tmp_file
  end




  # The Main Setup Task

  desc 'Setup base and all selected components'
  task setup: [:setup_base, :setup_components, :cleanup]


  task :setup_components do
    fetch(:host_components, []).each do |component|
      invoke "host:setup_#{component}"
    end
  end




  # Maintenance Tasks

  desc 'Cleanup host'
  task :cleanup do
    on roles(:all) do
      sudo :yum, '-y', 'clean', 'all'
      paths_to_rm = [
        '/etc/{.pwd.lock,group-,gshadow-,passwd-,shadow-}',
        '/home/ec2-user/{.dbshell,.gem,.gnupg,.irb-history,.mongorc.js,.mysql_history,.node-gyp,.npm,.pki,.pry_history,.rnd,.viminfo}',
        '/root/{.bash_history,.gem,.gnupg,.node-gyp,.npm,.pki,.rnd,.ssh,.viminfo}',
        '/tmp/{.ICE-unix,bundler*,hsperfdata_*,motd.*,npm-*,passenger_native_support*,spring}',
        '/var/log/{*.0,*.gz,*.old}',
        '/var/tmp/*'
      ]
      sudo :rm, '-fr', *paths_to_rm
    end
  end


  desc 'Run command on host'
  task :run_command, :command do |t, args|
    on roles(:all) do
      sudo :bash, '-c', '-l', "\"#{args[:command]}\""
    end
  end


  desc 'Update system software on host'
  task :update_system do
    on roles(:all) do
      sudo :yum, '-y', 'update'
      sudo :yum, '-y', 'clean', 'all'
    end
  end




  # Setup Base

  desc 'Setup base'
  task setup_base: [:base_set_ssh_authorized_keys, :base_set_host_name, :base_configure_cron, :update_system]


  task :base_configure_cron do
    on roles(:all) do
      upload_file("#{config_dir}/crontab", '/etc/cron.d/host') if File.exists?("#{config_dir}/crontab")
    end
  end


  task :base_set_host_name do
    on roles(:all) do |host|
      host_name = host.properties.host_name || 'host'
      sudo :hostname, host_name
      sudo :sed, '-i', "s/^HOSTNAME=.*/HOSTNAME=#{host_name}/g", '/etc/sysconfig/network'
    end
  end


  task :base_set_ssh_authorized_keys do
    on roles(:all) do
      upload_file("#{config_dir}/authorized_keys", '.ssh/authorized_keys', mod: 'u+rw,go-rwx') if File.exists?("#{config_dir}/authorized_keys")
    end
  end

end
