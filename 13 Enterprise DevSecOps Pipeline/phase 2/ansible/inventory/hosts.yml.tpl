all:
  children:
    jumpbox:
      hosts:
        vm-jumpbox:
          ansible_host: ${jumpbox_ip}
          ansible_user: ${admin_username}
          ansible_password: ${admin_password}
          ansible_connection: winrm
          ansible_winrm_transport: ntlm
          ansible_port: 5986
          ansible_winrm_server_cert_validation: ignore
