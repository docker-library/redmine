# What is this

Overrides docker-entrypoint.sh with original one to skip permission modification on /usr/src/redmine/files.


# How to use it

## Build image

```
docker build -t redmine:4.0-passenger-ds .
```

## Confirm it works at local

```
docker run -d --name redmine-ds -p 3000:3000 redmine:4.0-passenger-ds
```

## Push it to remote-repository and start to use it

For example, push to AWS ECR

```
aws ecr get-login --no-include-email
docker login -u AWS -p xxxxxxxxx
docker tag [image id] [ecr id].dkr.ecr.ap-southeast-1.amazonaws.com/ds-redmine
docker push [ecr id].dkr.ecr.ap-southeast-1.amazonaws.com/ds-redmine
```

