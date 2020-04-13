Feature: OVN related networking scenarios

  # @author rbrattai@redhat.com
  # @case_id OCP-28936
  @admin
  @destructive
  Scenario: Create/delete pods while forcing OVN leader election
  #Test for bug https://bugzilla.redhat.com/show_bug.cgi?id=1781297
    Given I have a project
    And evaluation of `project.name` is stored in the :usr_project clipboard

    Given I run the steps 4 times:
    """
    Given I have a pod-for-ping in the "<%= cb.usr_project %>" project
    Given I store the ovnkube-master "south" leader pod in the clipboard
    When admin deletes the ovnkube-master "south" leader
    Then the step should succeed
    When I store the ovnkube-master "south" leader pod in the :new_south_leader clipboard
    Then the step should succeed
    And the expression should be true> cb.south_leader.name != cb.new_south_leader.name
    And admin waits for all pods in the "openshift-ovn-kubernetes" project to become ready up to 60 seconds
    Given I ensure "hello-pod" pod is deleted from the "<%= cb.usr_project%>" project
    """


  # @author rbrattai@redhat.com
  # @case_id OCP-26092
  @admin
  @destructive
  Scenario: Pods and Services should keep running when a new raft leader gets be elected
    Given I store the ovnkube-master "south" leader pod in the clipboard
    Given I have a project
    And evaluation of `project.name` is stored in the :usr_project clipboard
    When I run the :create client command with:
      | f | <%= BushSlicer::HOME %>/testdata/networking/list_for_pods.json |
    Then the step should succeed
    Given 2 pods become ready with labels:
      | name=test-pods |
    And evaluation of `pod(0).node_name` is stored in the :node_name clipboard
    And evaluation of `pod(0).ip` is stored in the :pod1_ip clipboard
    And evaluation of `pod(1).name` is stored in the :pod2_name clipboard

    # Check pod works
    When I execute on the "<%= cb.pod2_name %>" pod:
      | curl | -s | --connect-timeout | 60 | <%= cb.pod1_ip%>:8080 |
    Then the step should succeed
    And the output should contain "Hello OpenShift"

    When admin deletes the ovnkube-master "south" leader
    Then the step should succeed

    When I store the ovnkube-master "south" leader pod in the :new_south_leader clipboard
    Then the step should succeed
    And the expression should be true> cb.south_leader.name != cb.new_south_leader.name
    And admin waits for all pods in the "openshift-ovn-kubernetes" project to become ready up to 60 seconds

    # Check pod works
    Given I use the "<%= cb.usr_project%>" project
    When I execute on the "<%= cb.pod2_name %>" pod:
      | curl | -s | --connect-timeout | 60 | <%= cb.pod1_ip%>:8080 |
    Then the step should succeed
    And the output should contain "Hello OpenShift"


  # @author rbrattai@redhat.com
  # @case_id OCP-26139
  @admin
  @destructive
  Scenario: Traffic flow shouldn't be interrupted when master switches the leader positions
    Given I switch to cluster admin pseudo user
    Given admin creates a project
    And evaluation of `project.name` is stored in the :iperf_project clipboard
    And admin uses the "<%= cb.iperf_project %>" project

    When I run the :create admin command with:
      | f | <%= BushSlicer::HOME %>/testdata/networking/iperf_nodeport_service.json |
    Then the step should succeed
    And the pod named "iperf-server" becomes ready
    And evaluation of `service("iperf-server").ip(user: user)` is stored in the :iperf_service_ip clipboard

    Given I store the ovnkube-master "south" leader pod in the clipboard
    Given I store the masters in the :masters clipboard

    # place directly on master
    When I run oc create as admin over "<%= BushSlicer::HOME %>/testdata/networking/egress-ingress/qos/iperf-server.json" replacing paths:
      | ["spec"]["containers"][0]["args"] | ["-c", "<%= cb.iperf_service_ip %>", "-u", "-J", "-t", "30"] |
      | ["spec"]["containers"][0]["name"] | "iperf-client"                                               |
      | ["metadata"]["name"]              | "iperf-client"                                               |
      | ["spec"]["nodeName"]              | "<%= cb.masters[0].name %>"                                  |
      | ["spec"]["hostNetwork"]           | true                                                         |
      | ["spec"]["restartPolicy"]         | "Never"                                                      |
    Then the step should succeed
    And the pod named "iperf-client" becomes ready

    When admin deletes the ovnkube-master "south" leader
    Then the step should succeed
    When I store the ovnkube-master "south" leader pod in the :new_south_leader clipboard
    Then the step should succeed
    And the expression should be true> cb.south_leader.name != cb.new_south_leader.name
    And admin waits for all pods in the "openshift-ovn-kubernetes" project to become ready up to 60 seconds
    Given I use the "<%= cb.iperf_project %>" project
    When the pod named "iperf-client" status becomes :succeeded within 120 seconds
    And I run the :logs client command with:
      | resource_name | iperf-client |
    Then the step should succeed
    And the output is parsed as JSON
    Then the expression should be true> @result[:parsed]['end']['sum']['lost_percent'].to_f < 10
    Then the expression should be true> @result[:parsed]['end']['sum']['bytes'].to_f > 1024
    Then the expression should be true> @result[:parsed]['end']['sum']['packets'].to_f > 0
    Then the expression should be true> @result[:parsed]['end']['sum']['jitter_ms'].to_f < 1
    And I run the :logs client command with:
      | resource_name | iperf-server |
    Then the step should succeed
    And the output is parsed as JSON
    Then the expression should be true> @result[:parsed]['end']['sum']['lost_percent'].to_f < 10
    # server doesn't count bytes
    Then the expression should be true> @result[:parsed]['end']['sum']['packets'].to_f > 0
    Then the expression should be true> @result[:parsed]['end']['sum']['jitter_ms'].to_f < 1


  # @author rbrattai@redhat.com
  # @case_id OCP-26089
  @admin
  @destructive
  Scenario: New raft leader should be elected if existing leader gets deleted or crashed in hybrid/non-hybrid clusters
    Given admin uses the "openshift-ovn-kubernetes" project
    When I store the ovnkube-master "north" leader pod in the clipboard
    Then the step should succeed
    Given admin ensures "<%= cb.north_leader.name %>" pod is deleted from the "openshift-ovn-kubernetes" project
    Then the step should succeed
    And I wait up to 30 seconds for the steps to pass:
    """
    When I store the ovnkube-master "north" leader pod in the :new_north_leader clipboard
    Then the step should succeed
    And the expression should be true> cb.north_leader.name != cb.new_north_leader.name
    """
    And admin waits for all pods in the project to become ready up to 60 seconds


  # @author rbrattai@redhat.com
  # @case_id OCP-26091
  @admin
  @destructive
  Scenario: New raft leader should be elected if SB db on existing master is crashed
    Given admin uses the "openshift-ovn-kubernetes" project
    When I store the ovnkube-master "south" leader pod in the clipboard
    Then the step should succeed
    When the OVN "south" database is killed on the "<%= cb.south_leader.node_name %>" node
    Then the step should succeed

    And I wait up to 30 seconds for the steps to pass:
    """
    When I store the ovnkube-master "south" leader pod in the :new_south_leader clipboard
    Then the step should succeed
    And the expression should be true> cb.south_leader != cb.new_south_leader
    """
    And admin waits for all pods in the project to become ready up to 60 seconds


  # @author rbrattai@redhat.com
  # @case_id OCP-26138
  @admin
  @destructive
  Scenario: Inducing Split Brain in the OVN HA cluster
    Given admin uses the "openshift-ovn-kubernetes" project
    When I store the ovnkube-master "south" leader pod in the clipboard
    Then the step should succeed

    Given I select a random master not named "<%= cb.south_leader.node_name %>"
    # don't block all traffic that breaks etcd, just block the OVN ssl ports
    When I run commands on the host:
      | iptables -t filter -A INPUT -s <%= cb.south_leader.ip %> -p tcp --dport 9643:9644 -j DROP |
    Then the step should succeed

    And I wait up to 30 seconds for the steps to pass:
    """
    When I store the ovnkube-master "south" leader pod in the :new_south_leader clipboard
    Then the step should succeed
    And the expression should be true> cb.south_leader == cb.new_south_leader
    """
    When I run commands on the host:
      | iptables -t filter -D INPUT -s <%= cb.south_leader.ip %> -p tcp --dport 9643:9644 -j DROP |
    And I wait up to 30 seconds for the steps to pass:
    """
    When I store the ovnkube-master "south" leader pod in the :new_south_leader clipboard
    Then the step should succeed
    And the expression should be true> cb.south_leader == cb.new_south_leader
    """
    And admin waits for all pods in the project to become ready up to 60 seconds


  # @author rbrattai@redhat.com
  # @case_id OCP-26140
  @admin
  @destructive
  Scenario: Delete all OVN master pods and makes sure leader/follower election converges smoothly
    Given admin uses the "openshift-ovn-kubernetes" project
    When I store the ovnkube-master "north" leader pod in the clipboard
    Then the step should succeed
    When I run the :delete admin command with:
      | object_type | pod                |
      | l           | app=ovnkube-master |
    Then the step should succeed
    And I wait up to 30 seconds for the steps to pass:
    """
    When I store the ovnkube-master "north" leader pod in the :new_north_leader clipboard
    Then the step should succeed
    And the expression should be true> cb.north_leader.name != cb.new_north_leader.name
    """
    And admin waits for all pods in the project to become ready up to 60 seconds

