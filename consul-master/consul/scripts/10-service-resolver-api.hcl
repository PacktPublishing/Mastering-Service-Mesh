kind = "service-resolver"
name = "api"

# Using a default_subset will route traffic to the subset specified in the value when no traffic-splitter is present. 

default_subset = "v1"

subsets = {
  v1 = {
    filter = "Service.Meta.version == 1"
  }
  v2 = {
    filter = "Service.Meta.version == 2"
  }
}
