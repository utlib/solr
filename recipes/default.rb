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

directory "#{node[:solr][:data_path]}" do
  owner "#{node[:tomcat][:user]}"
  group "#{node[:tomcat][:user]}"
  mode "0755"
  recursive true
  action :create
end



## install solr
if node[:solr][:installed] == false
  script "install_solr" do
    interpreter "bash"
    user "root"
    cwd "#{Chef::Config[:file_cache_path]}"
    code <<-EOH
    wget http://www.apache.org/dist/lucene/solr/#{node[:solr][:version]}/apache-solr-#{node[:solr][:version]}.tgz
    tar -zxf apache-solr-#{node[:solr][:version]}.tgz
    cp -f apache-solr-#{node[:solr][:version]}/dist/apache-solr-#{node[:solr][:version]}.war #{node[:tomcat][:webapp_dir]}/solr.war
    cp -fr apache-solr-#{node[:solr][:version]}/example/solr #{node[:tomcat][:base]}/
    chown -R #{node[:tomcat][:user]}.#{node[:tomcat][:user]} #{node[:tomcat][:base]}
    EOH
  end
  template "#{node[:tomcat][:base]}/solr/conf/solrconfig.xml" do
    source "solrconfig.xml.#{node[:solr][:version]}.erb"
    owner "#{node[:tomcat][:user]}"
    group "#{node[:tomcat][:user]}"
    mode 0644
    notifies :restart, "service[tomcat]"
  end
  if node[:solr][:multicore] == true
    node[:solr][:core_names].each do |core|
      directory "#{node[:tomcat][:base]}/solr/#{core}" do
        owner "#{node[:tomcat][:user]}"
        group "#{node[:tomcat][:user]}"
        mode "0755"
        action :create
      end
      execute "copydir" do
        command "cp -pr #{node[:tomcat][:base]}/solr/conf #{node[:tomcat][:base]}/solr/#{core}"
        action :run
      end
      ruby_block 'editconfig' do
        block do
          configedit = Chef::Util::FileEdit.new("#{node[:tomcat][:base]}/solr/#{core}/conf/solrconfig.xml")
              if configedit.search_line(/#{node[:solr][:data_path]}/)
                configedit.search_file_replace(/#{node[:solr][:data_path]}/, "#{node[:solr][:data_path]}/#{core}")
              end
          configedit.write_file
          end
      end
    end
    template "#{node[:tomcat][:base]}/solr/solr.xml" do
      source "solr.xml-multicore.erb"
      owner "#{node[:tomcat][:user]}"
      group "#{node[:tomcat][:user]}"
      mode 0644
      notifies :restart, "service[tomcat]"
    end
  end
  execute "setperms" do
    command "chown -R #{node[:tomcat][:user]}.#{node[:tomcat][:user]} #{node[:tomcat][:base]}"
    action :run
  end
  node.normal[:solr][:installed] = true
  node.save
end

template "#{node[:tomcat][:context_dir]}/solr.xml" do
  source "solr.xml.erb"
  owner "root"
  group "#{node[:tomcat][:user]}"
  mode 0644
  notifies :restart, "service[tomcat]"
end
