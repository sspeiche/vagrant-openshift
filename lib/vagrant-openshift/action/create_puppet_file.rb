#--
# Copyright 2013 Red Hat, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#++

module Vagrant
  module Openshift
    module Action
      class CreatePuppetFile
        include CommandHelper

        def initialize(app, env)
          @app = app
          @env = env
        end

        def call(env)
          hostname = env[:machine].config.vm.hostname
          domain = env[:machine].config.openshift.cloud_domain
          key,_ = sudo(env[:machine], "cat /var/named/K#{domain}.*.key")
          key = key.first.strip.split(' ')
          key = "#{key[6]}#{key[7]}"

          links,_ = sudo(env[:machine], "ip link")
          links = links.map!{ |l| l.split("\n") }.flatten

          links.map! do |link|
            m = link.match(/[0-9]+: ([a-z0-9]+):/)
            m.nil?? "lo" : m[1]
          end
          links.delete "lo"

          remote_write(env[:machine], "#{Constants.build_dir}/configure_origin.pp") {
            config = "
class { 'openshift_origin' :
  domain                     => '#{domain}',
  broker_hostname            => '#{hostname}',
  node_hostname              => '#{hostname}',
  named_hostname             => '#{hostname}',
  datastore_hostname         => '#{hostname}',
  activemq_hostname          => '#{hostname}',
  openshift_user1            => 'admin',
  openshift_password1        => 'admin',
  bind_key                   => '#{key}',
  override_install_repo      => 'file://#{Constants.build_dir}/origin-rpms',
  development_mode           => true,
  conf_node_external_eth_dev => '#{links.first}',
  register_host_with_named   => true,
  broker_auth_plugin         => 'mongo',
  node_unmanaged_users       => ['#{env[:machine].ssh_info[:username]}'],
  node_container_plugin      => '#{env[:machine].config.openshift.container}'"
            env[:machine].config.openshift.advanced_puppet_values.each do |k,v|
              config += %{  #{k} => #{v}\n}
            end
            config += "}"
            config
          }

          @app.call(env)
        end
      end
    end
  end
end