namespace :host do

  desc 'Setup New Relic'
  task setup_new_relic: [:new_relic_install, :new_relic_configure, :new_relic_enable]


  task :new_relic_configure do
    on roles(:all) do
      sudo :mkdir, '-p', '/etc/newrelic'
      upload_file('config/nrsysmond.cfg', '/etc/newrelic/nrsysmond.cfg')
    end
  end


  task :new_relic_enable do
    on roles(:all) do
      sudo :service, 'newrelic-sysmond', 'start'
      sudo :chkconfig, 'newrelic-sysmond', 'on'
    end
  end


  task :new_relic_install do
    on roles(:all) do
      sudo :bash, '-c', '"if rpm -q newrelic-repo ; then rpm -e newrelic-repo ; fi"'
      sudo :rpm, '-Uvh', 'https://yum.newrelic.com/pub/newrelic/el5/x86_64/newrelic-repo-5-3.noarch.rpm'
      sudo :yum, '-y', 'install', 'newrelic-sysmond'
    end
  end

end
