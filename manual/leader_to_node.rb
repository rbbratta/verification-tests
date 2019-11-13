#!/usr/bin/env ruby


require 'open3'
require 'json'

require_relative 'find_leader'

OVN_NAMESPACE = "openshift-ovn-kubernetes"

def first_master(status_command)

  stdout, stderr, err = Open3.capture3("oc get pod -n #{OVN_NAMESPACE} -l name=ovnkube-master -o jsonpath='{.items[0].metadata.name}'")
  the_pod = stdout.strip

  stdout, stderr, err = Open3.capture3("oc -n #{OVN_NAMESPACE} exec #{the_pod} -c northd -- #{status_command}")
  cluster_state = stdout.strip

  leader = find_leader(cluster_state)
  leader_host = leader_hostname(leader)[1]

  stdout, stderr, err = Open3.capture3("oc get pod -n #{OVN_NAMESPACE} -l name=ovnkube-master --field-selector spec.nodeName=#{leader_host} -o jsonpath='{.items[0].metadata.name}'")
  stdout.strip

end

def first_running(pods)
  pods["items"].each do |p|
    if p["status"]["phase"] == "Running"
      return p["metadata"]["name"]
    end
  end
end

def get_pods
  stdout, stderr, err = Open3.capture3("oc get pod -n #{OVN_NAMESPACE} -l name=ovnkube-master -o json")
  pods = JSON.parse(stdout)
end

def first_master_json(status_command)

  pods = get_pods

  the_pod = first_running(pods)
  # the_pod = pods["items"][0]["metadata"]["name"]

  stdout, stderr, err = Open3.capture3("oc -n #{OVN_NAMESPACE} exec #{the_pod} -c northd -- #{status_command}")
  cluster_state = stdout.strip

  leader_line = find_leader(cluster_state)
  # puts leader_line
  leader_host = leader_hostname(leader_line)[1]
  # puts leader_host

  pods["items"].each do |p|
    if p["spec"]["nodeName"] == leader_host || p["status"]["podIP"] == leader_host
      return p["metadata"]["name"]
    end
  end

end

def get_commandline(arg)
  case arg
  when "north"
    ovs_database = "ovs-appctl -t /var/run/openvswitch/ovnnb_db.ctl cluster/status OVN_Northbound"
  else
    ovs_database = "ovs-appctl -t /var/run/openvswitch/ovnsb_db.ctl cluster/status OVN_Southbound"
  end
  ovs_database
end

if $0 == __FILE__
  ARGV.each do |arg|
    ovs_database = get_commandline(arg)
    puts first_master_json(ovs_database)
  end

end
