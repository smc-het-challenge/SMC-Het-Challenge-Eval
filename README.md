
System Install

```
sudo useradd -s /bin/bash -m ubuntu
sudo usermod -aG google-sudoers ubuntu
```

```
sudo apt-get update
sudo apt-get install -y git
git clone https://github.com/kellrott/SMC-Het-Challenge-Eval.git
 
cd SMC-Het-Challenge-Eval/
bash deploy_setup_new.sh
```