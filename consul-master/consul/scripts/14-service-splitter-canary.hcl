kind = "service-splitter",
name = "api"

splits = [
  {
    weight = 99,
    service_subset = "v1"
  },
  {
    weight = 1,
    service_subset = "v2"
  }
]
