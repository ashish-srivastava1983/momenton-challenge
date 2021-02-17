variable env {
  default = "training"
}

variable region_aus {
  description = "GCP Region"
  type        = string
  default     = "australia-southeast1"
}

variable availability_zones_aus {
  description = "The zone location for the VM"
  type        = list(string)
  default     = ["australia-southeast1-a","australia-southeast1-b","australia-southeast1-c"]
}

variable web_tier_node_size {
  description = "Web tier node target size"
  type        = number
  default     = 1
}
