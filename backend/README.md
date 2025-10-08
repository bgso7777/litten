# account manager api

- app path : /var/workspace/account
- port : 8989
- context-path : /account
- url-exam : http://localhost:8989/account

# spring.profiles
- local : local pc 환경
- idc : idc 개발
- dev : aws 개발
- qa : aws qa
- prod : aws production

# vm args :
- -Dspring.profiles.active=idc
- -Dapp.home=/var/workspace/account
- -DLOG_PATH=$app.home/logs

# vm args for eclipse
- -Dapp.home=${workspace_loc:accountManager}
- -DLOG_DIR=${workspace_loc:accountManager}/logs

# 배포환경
- git update-index --chmod=+x .\dev\run.sh
