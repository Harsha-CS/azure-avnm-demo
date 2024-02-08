locals {
    # Enable flow log retention policy for 7 days
    flow_logs_enabled = true
    flow_logs_retention_policy_enabled = true
    flow_logs_retention_days = 7

    # Enable traffic anlaytics for the network security group and set the interval to 60 minutes
    traffic_analytics_enabled = true
    traffic_analytics_interval_in_minutes = 60
}