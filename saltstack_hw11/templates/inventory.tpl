[all]
%{ for master in masters ~}
${ master["name"] } ansible_host=${ master.network_interface[0].ip_address } ip=${ master.network_interface[0].ip_address } public_ip=${ master.network_interface[0].nat_ip_address }
%{ endfor ~}
%{ for be in bes ~}
${ be["name"] } ansible_host=${ be.network_interface[0].ip_address } ip=${ be.network_interface[0].ip_address } public_ip=${ be.network_interface[0].nat_ip_address }
%{ endfor ~}
%{ for lb in lbs ~}
${ lb["name"] } ansible_host=${ lb.network_interface[0].ip_address } ip=${ lb.network_interface[0].ip_address } public_ip=${ lb.network_interface[0].nat_ip_address }
%{ endfor ~}

[masters]
%{ for master in masters ~}
${ master["name"] }
%{ endfor ~}

[dbs]
%{ for db in dbs ~}
${ db["name"] }
%{ endfor ~}

[bes]
%{ for be in bes ~}
${ be["name"] }
%{ endfor ~}

[lbs]
%{ for lb in lbs ~}
${ lb["name"] }
%{ endfor ~}

[all:vars]
ansible_ssh_common_args='-o StrictHostKeyChecking=no -o ProxyJump="${ remote_user }@${ masters[0].network_interface[0].nat_ip_address }"'
#ansible_ssh_common_args='-o StrictHostKeyChecking=no -o ProxyCommand="ssh -p 22 -W %h:%p -q ${ remote_user }@${ masters[0].network_interface[0].nat_ip_address }"'