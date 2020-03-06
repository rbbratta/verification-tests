Feature: OVN related networking scenarios

  # @author rbrattai@redhat.com
  # @case_id OCP-26139
  @admin
  @destructive
  Scenario: Repeat delete and creation
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
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/networking/list_for_pods.json |
    Then the step should succeed
    Given 2 pods become ready with labels:
      | name=test-pods |
    And evaluation of `pod(0).node_name` is stored in the :node_name clipboard
    And evaluation of `pod(0).ip` is stored in the :pod1_ip clipboard
    And evaluation of `pod(1).name` is stored in the :pod2_name clipboard

    # Check pod works
    Given I wait up to 60 seconds for the steps to pass:
    """
    When I execute on the "<%= cb.pod2_name%>" pod:
      | curl | <%= cb.pod1_ip%>:8080 |
    Then the step should succeed
    And the output should contain "Hello OpenShift"
    """

    When admin deletes the ovnkube-master "south" leader
    Then the step should succeed

    When I store the ovnkube-master "south" leader pod in the :new_south_leader clipboard
    Then the step should succeed
    And the expression should be true> cb.south_leader.name != cb.new_south_leader.name
    And admin waits for all pods in the "openshift-ovn-kubernetes" project to become ready up to 60 seconds

    # Check pod works
    Given I use the "<%= cb.usr_project%>" project
    And I wait up to 60 seconds for the steps to pass:
    """
    When I execute on the "<%= cb.pod2_name%>" pod:
      | curl | <%= cb.pod1_ip%>:8080 |
    Then the step should succeed
    And the output should contain "Hello OpenShift"
    """


#  # @author rbrattai@redhat.com
#  # @case_id OCP-26139
#  @admin
#  @destructive
#  Scenario: Traffic flow shouldn't be interrupted when master switches the leader positions
#    Given I have a project
#    Given I have a pod-for-ping in the project
#    Given I have a pod-for-ping in the "<%= cb.usr_project %>" project
#    Given I store the ovnkube-master "south" leader pod in the clipboard
#    When admin deletes the ovnkube-master "south" leader
#    Then the step should succeed
#    When I store the ovnkube-master "south" leader pod in the :new_south_leader clipboard
#    Then the step should succeed
#    And the expression should be true> cb.south_leader.name != cb.new_south_leader.name
#    And admin waits for all pods in the "openshift-ovn-kubernetes" project to become ready up to 60 seconds
#    Given I ensure "hello-pod" pod is deleted from the "<%= cb.usr_project%>" project
