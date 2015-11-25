// This script expects the aws key and secret as variables. This is necessary because we need access to the aws varialbes during the provisioning step.
// e.g. terraform apply -var 'access_key=......' -var 'secret_key=......' .

// So, first run 'terraform get'
// Finally, run the plan and apply steps to create the cluster. You can also provide the aws credentials with environmental variables like: TF_VAR_access_keys...

module "ssh_keys" {
  source = "ssh_keys"
  name = "key"
}

resource "aws_instance" "mesos-master" {

  count = 1
  ami   = "${lookup(var.aws_amis, var.aws_region)}"

  instance_type = "t2.large"
  key_name      = "${module.ssh_keys.key_name}"
  subnet_id     = "${aws_subnet.terraform.id}"

  vpc_security_group_ids = ["${aws_security_group.terraform.id}"]

  tags { Name = "mesos-master-${count.index}" }

  connection {
    user     = "ubuntu"
    key_file = "${module.ssh_keys.private_key_path}"
  }

  provisioner "remote-exec" {
    inline = [
      "while [ ! -f /var/lib/cloud/instance/boot-finished ]; do sleep 1; done"
    ]
  }

  provisioner "file" {
        source = "provision.sh"
        destination = "/tmp/provision.sh"
    }

    provisioner "remote-exec" {
        inline = [
          "chmod +x /tmp/provision.sh",
          "/tmp/provision.sh localhost ${var.access_key} ${var.secret_key}"
        ]
    }
}

resource "aws_instance" "mesos-agent" {
  count = 3
  ami   = "${lookup(var.aws_amis, var.aws_region)}"

  instance_type = "t2.large"
  key_name      = "${module.ssh_keys.key_name}"
  subnet_id     = "${aws_subnet.terraform.id}"

  vpc_security_group_ids = ["${aws_security_group.terraform.id}"]

  tags { Name = "mesos-agent-${count.index}" }

  connection {
    user     = "ubuntu"
    key_file = "${module.ssh_keys.private_key_path}"
  }

  provisioner "remote-exec" {
    inline = [
      "while [ ! -f /var/lib/cloud/instance/boot-finished ]; do sleep 1; done"
    ]
  }

  provisioner "file" {
        source = "provision.sh"
        destination = "/tmp/provision.sh"
    }

    provisioner "remote-exec" {
        inline = [
          "chmod +x /tmp/provision.sh",
          "/tmp/provision.sh ${aws_instance.mesos-master.public_dns} ${var.access_key} ${var.secret_key}" 
        ]
    }
}

output "# SSH key" { value = "\nexport KEY=$PWD/ssh_keys/key.pem" }
output "# Master" { value = "\nexport MASTER=${aws_instance.mesos-master.public_dns}" }
output "# Slave 0" { value = "\nexport SLAVE0=${aws_instance.mesos-agent.0.public_dns}" }
output "# Slave 1" { value = "\nexport SLAVE1=${aws_instance.mesos-agent.1.public_dns}" }
output "# Slave 2" { value = "\nexport SLAVE2=${aws_instance.mesos-agent.2.public_dns}" }

