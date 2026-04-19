output "attack_hosts" {
  description = "Map of Name -> { instance_id, private_ip } for each attack host."
  value = {
    for k, v in aws_instance.attack_host : k => {
      instance_id = v.id
      private_ip  = v.private_ip
    }
  }
}
