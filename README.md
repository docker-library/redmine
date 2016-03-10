# redmine
Docker Image for Redmine

Please note:

The MySQL container must have set the following environment variables:
 - MYSQL_DATABASE
 - MYSQL_USER
 - MYSQL_PASSWORD
Redmine only supports MySQL 5.6, not 5.7

Run MySQL Database, e.g.:

    docker run -d --name redmine-mysql -e MYSQL_RANDOM_ROOT_PASSWORD=1 \
                                       -e MYSQL_DATABASE=redmine \
                                       -e MYSQL_USER=redmine \
                                       -e MYSQL_PASSWORD=123456 \
           mysql:5.6

Now connect Redmine:

    docker run -d --name redmine --link redmine-mysql:mysql -p 8123:80 mwaeckerlin/redmine

Initial username/password is: admin/admin

Possible ServiceDock Configuration:
```
[
  {
    "name": "redmine-mysql",
    "image": "mysql:5.6",
    "ports": [],
    "env": [
      "MYSQL_ROOT_PASSWORD=123456",
      "MYSQL_DATABASE=redmine",
      "MYSQL_USER=redmine",
      "MYSQL_PASSWORD=123456"
    ],
    "cmd": null,
    "volumesfrom": [],
    "links": [],
    "volumes": []
  },
  {
    "name": "redmine",
    "image": "mwaeckerlin/redmine",
    "ports": [
      {
        "internal": "80/tcp",
        "external": "8123",
        "ip": null
      }
    ],
    "env": [],
    "cmd": [
      "bash"
    ],
    "entrypoint": null,
    "volumesfrom": [],
    "links": [
      {
        "container": "redmine-mysql",
        "name": "mysql"
      }
    ],
    "volumes": []
  }
]
```
