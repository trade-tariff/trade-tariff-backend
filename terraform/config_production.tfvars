region        = "eu-west-2"
environment   = "production"
cpu           = 2048
memory        = 4096
service_count = 4
min_capacity  = 2
max_capacity  = 16
# Temporarily pinned autoscaling cooldown values in Production to preserve existing behaviour while testing changes in dev and staging
# Can also remove those variables (in variables.tf) if we decide to keep the default cooldown values
scale_in_cooldown  = 0
scale_out_cooldown = 0
