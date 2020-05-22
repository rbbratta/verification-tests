Feature: OVN related networking scenarios


  # @author rbrattai@redhat.com
  # @case_id OCP-32059
  # BZ-1809747
  @admin
  @destructive
  Scenario: OVN Northd HA switches after inactivity_probe times out
    Given the env is using "OVNKubernetes" networkType
    Given I switch to cluster admin pseudo user
    Given admin uses the "openshift-ovn-kubernetes" project
    When I store the ovnkube-master "south" leader pod in the clipboard
    Then the step should succeed
    When I store the active ovn_nortd pod in the clipboard

    """
    Get the inactivity probe seoncds
    Stuff and things
    So enable debug logging using configmap
    Find the northd pod with the lock
    Pause the northd process with the lock
    Wait for 2 * inactivity_probe secondss
    Check the logs to ensure a new pod has acquired the lock
    Unpause the old pod
    Check the lock stays the same
    """

