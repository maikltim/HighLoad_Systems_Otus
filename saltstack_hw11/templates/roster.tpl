%{ for master in masters ~}
${ master["name"] }:
  host: ${ master.network_interface[0].nat_ip_address }
  user: cloud-user
  priv: /home/user/.ssh/otus
  sudo: True  
%{ endfor ~}

%{ for db in dbs ~}
${ db["name"] }:
  host: ${ db.network_interface[0].nat_ip_address }
  user: cloud-user
  priv: /home/user/.ssh/otus
  sudo: True  
%{ endfor ~}

%{ for be in bes ~}
${ be["name"] }:
  host: ${ be.network_interface[0].nat_ip_address }
  user: cloud-user
  priv: /home/user/.ssh/otus
  sudo: True  
%{ endfor ~}

%{ for lb in lbs ~}
${ lb["name"] }:
  host: ${ lb.network_interface[0].nat_ip_address }
  user: cloud-user
  priv: /home/user/.ssh/otus
  sudo: True  
%{ endfor ~}