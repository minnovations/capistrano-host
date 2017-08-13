namespace :host do

  desc 'Setup EC2 Host Tools'
  task setup_ec2_host_tools: [:ec2_host_tools_install]


  task :ec2_host_tools_install do
    on roles(:all) do
      sudo :gem, 'install', 'specific_install'
      sudo :gem, 'specific_install', 'https://github.com/minnovations/ec2-host-tools.git'
    end
  end

end
