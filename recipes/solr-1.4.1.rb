#
# Cookbook Name:: solr
# Recipe:: default
#
# Copyright 2012, UTL
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

include_recipe "tomcat"
include_recipe "java"
include_recipe "ark"

#make dir to dump tgz in
directory "#{node['solr']['install_path']}" do
  owner "root"
  group "root"
  mode "0755"
  action :create
end

# make /root_path if it doesn't exist
directory "#{node['solr']['root_path']}" do
  owner "root"
  group "root"
  mode "0755"
  action :create
end

# make solr data dir if it doesn't exist
directory "#{node['solr']['data_path']}" do
  owner "#{node['tomcat']['user']}"
  group "#{node['tomcat']['user']}"
  mode "0755"
  action :create
end

ark "apache-solr-#{node['solr']['version']}" do
  url "http://#{node['repo_server']}/solr/apache-solr-#{node['solr']['version']}.tgz"
  path "#{node['solr']['install_path']}"
  checksum "d795bc477335b3e29bab7073b385c93fca4be867aae345203da0d1e438d7543f"
  owner "root"
  creates "README.txt"
  action :put
end

### prepare solr files
bash "prepare_solr" do
  user "root"
  cwd "/tmp"
  code <<-EOH
    cp -f #{node['solr']['install_path']}/apache-solr-#{node['solr']['version']}/dist/apache-solr-#{node['solr']['version']}.war #{node[:tomcat][:webapp_dir]}/solr.war
    cp -fr #{node['solr']['install_path']}/apache-solr-#{node[:solr][:version]}/example/solr #{node[:tomcat][:base]}/
    chown -R #{node[:tomcat][:user]}.#{node[:tomcat][:user]} #{node[:tomcat][:base]}
    #sleep 8
  EOH
  not_if "test -f #{node[:tomcat][:webapp_dir]}/solr.war"
end
  
### put solrconfig in place, but don't change it here: allow for other cookbooks, roles, or manual edits
template "#{node[:tomcat][:base]}/solr/conf/solrconfig.xml" do
  source "solrconfig.xml.#{node[:solr][:version]}.erb"
  owner "#{node[:tomcat][:user]}"
  group "#{node[:tomcat][:user]}"
  mode 0644
  notifies :restart, "service[tomcat]"
  not_if "test -f #{node[:tomcat][:base]}/solr/conf/solrconfig.xml"
  retries 10
  retry_delay 10  
end

if node[:solr][:multicore] == true
  node[:solr][:core_names].each do |core|
    ### make the core directory
    directory "#{node[:tomcat][:base]}/solr/#{core}" do
      owner "#{node[:tomcat][:user]}"
      group "#{node[:tomcat][:user]}"
      mode "0755"
      action :create
    end
    ### copy the base solr config files in
    bash "copysolr#{core}" do
      user "root"
      cwd "/tmp"
      code <<-EOH
        cp -pr #{node[:tomcat][:base]}/solr/conf #{node[:tomcat][:base]}/solr/#{core}
      EOH
      not_if "test -f #{node[:tomcat][:base]}/solr/#{core}/conf/solrconfig.xml"
    end
    ### edit the config file to point to the defined data directory for the core
    ruby_block "edit#{core}config" do
      block do
        configedit = Chef::Util::FileEdit.new("#{node[:tomcat][:base]}/solr/#{core}/conf/solrconfig.xml")
        configedit.search_file_replace(/#{node[:solr][:data_path]}\}/, "#{node[:solr][:data_path]}/#{core}\}")
        configedit.write_file
        end
    end
    bash "set_solr_perms#{core}" do
      user "root"
      cwd "/tmp"
      code <<-EOH
        chown -R #{node[:tomcat][:user]}.#{node[:tomcat][:user]} #{node[:tomcat][:base]}
      EOH
      not_if "test `stat -c %U #{node[:tomcat][:base]}/solr/#{core}/solrconfig.xml` = tomcat6"
    end
  end
  
  ### put solr.xml in place to describe the cores
  template "#{node[:tomcat][:base]}/solr/solr.xml" do
    source "solr.xml-multicore.#{node[:solr][:version]}.erb"
    owner "#{node[:tomcat][:user]}"
    group "#{node[:tomcat][:user]}"
    mode 0644
    notifies :restart, "service[tomcat]"
  end
end

template "#{node[:tomcat][:context_dir]}/solr.xml" do
  source "solr.xml.#{node[:solr][:version]}.erb"
  owner "root"
  group "#{node[:tomcat][:user]}"
  mode 0644
  notifies :restart, "service[tomcat]"
end


