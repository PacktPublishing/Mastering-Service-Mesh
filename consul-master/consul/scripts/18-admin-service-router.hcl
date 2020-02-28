kind = "service-router"
name = "admin"
routes = [
  {
    match {
      http {
        path_prefix = "/payment"
      }
    }

    destination {
      service = "payment"
    }
  },
]
