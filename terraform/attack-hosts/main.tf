resource "aws_instance" "attack_host" {
  for_each = var.attack_hosts

  ami                    = coalesce(each.value.ami_id, var.default_ami_id)
  instance_type          = coalesce(each.value.instance_type, var.default_instance_type)
  subnet_id              = coalesce(each.value.subnet_id, var.default_subnet_id)
  vpc_security_group_ids = var.security_group_ids
  key_name               = var.key_name
  ebs_optimized          = true

  metadata_options {
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
    http_endpoint               = "enabled"
  }

  root_block_device {
    volume_size           = var.root_volume_size_gb
    volume_type           = "gp3"
    iops                  = 3000
    throughput            = 125
    delete_on_termination = true
    encrypted             = false
  }

  tags = {
    Name = each.key
  }
}
