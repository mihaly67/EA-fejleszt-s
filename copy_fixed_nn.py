import paramiko
import os

def upload_file(host, user, key_path, local_path, remote_path):
    print(f"Connecting to {host}...")
    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    try:
        key = paramiko.Ed25519Key.from_private_key_file(key_path)
        client.connect(host, username=user, pkey=key, timeout=20)
        sftp = client.open_sftp()
        sftp.put(local_path, remote_path)
        sftp.close()
        print(f"Successfully uploaded {local_path} to {remote_path}")
    except Exception as e:
        print(f"Error: {e}")
    finally:
        client.close()

upload_file("100.77.191.66", "Jules", os.path.expanduser("~/.ssh/jules_key"), "Micro_LGBM/src/nn_meta_advisor.py", "/home/Jules/LGBM_mlops/Micro_LGBM/src/nn_meta_advisor.py")
