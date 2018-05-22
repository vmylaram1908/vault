#
# Cookbook:: vault
# Recipe:: default
#
# Copyright:: 2018, The Authors, All Rights Reserved.

group node['vault']['group'] do
end

user node['vault']['user'] do
  group node['vault']['group']
  system true
end

['unzip', 'libselinux-python', 'nss'].each do |package|
  yum_package package do
    action :upgrade
    ignore_failure true
  end
end

directory node['vault']['data'] do
  owner node['vault']['user']
  group node['vault']['group']
  recursive true
  action :create
  mode '0700'
end

directory node['vault']['install'] do
  owner node['vault']['user']
  group node['vault']['group']
  recursive true
  action :create
  mode '0700'
end

remote_file "#{Chef::Config[:file_cache_path]}/#{node['vault']['version']}_linux_amd64.zip" do
  source "#{node['vault']['artifactory']}#{node['vault']['version']}_linux_amd64.zip"
  mode '0755'
  action :create
  notifies :run, 'execute[unzip_vault]', :immediately
end

execute 'unzip_vault' do
  command "unzip #{Chef::Config[:file_cache_path]}/#{node['vault']['version']}_linux_amd64.zip -d #{node['vault']['install']}"
  not_if { ::File.exist?("#{node['vault']['install']}/vault") }
end

execute 'systemctl-daemon-reload' do
  command '/bin/systemctl --system daemon-reload'
  action :nothing
end

link '/apps/installs/vault' do
    to '/root/bin'
    only_if 'test -f /apps/installs/vault'
end

template '/apps/installs/vault/server.hcl' do
    source 'vault/server.hcl.erb'
    owner node['vault']['user']
    group node['vault']['group']
    mode '0755'
    action :create
    notifies :restart, 'service[vault]', :delayed
end

template '/etc/systemd/system/vault.service' do
  source 'vault/vault.service.erb'
  owner node['vault']['user']
  group node['vault']['group']
  mode '0755'
  action :create
  notifies :run, 'execute[systemctl-daemon-reload]', :immediately
  notifies :restart, 'service[vault]', :delayed
end

service 'vault' do
  supports status: true, restart: true, reload: true
  action   [:start, :enable]
end

include_recipe 'vault::vault_init'
