import paramiko
import os

def check():
    host = os.environ.get('VPS_HOST', '5.189.163.88')
    user = os.environ.get('VPS_USER', 'misi')
    password = os.environ.get('VPS_PASS', '1104')

    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())

    try:
        client.connect(hostname=host, username=user, password=password, timeout=10)

        # Kutassuk át a gui_rag.db-t az X-tengely (timeScale / minimumWidth / sync) kulcsszavakra
        cmd = "cd /home/misi/LGBM_mlops/Knowledge_Base/External_Repos/ && python3 gui_rag_builder.py --query timeScale sync"
        stdin, stdout, stderr = client.exec_command(cmd)
        print(stdout.read().decode('utf-8'))

        cmd = "cd /home/misi/LGBM_mlops/Knowledge_Base/External_Repos/ && python3 gui_rag_builder.py --query subchart align"
        stdin, stdout, stderr = client.exec_command(cmd)
        print(stdout.read().decode('utf-8'))

    finally:
        client.close()

if __name__ == "__main__":
    check()
