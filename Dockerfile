FROM ubuntu
MAINTAINER mwaeckerlin

EXPOSE 80

RUN apt-get update
RUN ( echo "redmine redmine/instances/default/mysql/admin-pass password"; \
      echo "redmine redmine/instances/default/app-password-confirm password"; \
      echo "# PostgreSQL application password for redmine/instances/default:"; \
      echo "redmine redmine/instances/default/pgsql/app-pass password"; \
      echo "redmine redmine/instances/default/pgsql/admin-pass password"; \
      echo "# MySQL application password for redmine/instances/default:"; \
      echo "redmine redmine/instances/default/mysql/app-pass password"; \
      echo "redmine redmine/instances/default/password-confirm password"; \
      echo "redmine redmine/old-instances string"; \
      echo "redmine redmine/instances/default/mysql/admin-user string root"; \
      echo "# Reinstall database for redmine/instances/default?"; \
      echo "redmine redmine/instances/default/dbconfig-reinstall boolean false"; \
      echo "redmine redmine/instances/default/missing-db-package-error select abort"; \
      echo "# Connection method for PostgreSQL database of redmine/instances/default:"; \
      echo "redmine redmine/instances/default/pgsql/method select unix socket"; \
      echo "# Host running the server for redmine/instances/default:"; \
      echo "redmine redmine/instances/default/remote/newhost string"; \
      echo "redmine redmine/instances/default/remote/port string"; \
      echo "# Do you want to back up the database for redmine/instances/default before upgrading?"; \
      echo "redmine redmine/instances/default/upgrade-backup boolean true"; \
      echo "redmine redmine/instances/default/pgsql/changeconf boolean false"; \
      echo "# redmine- package required"; \
      echo "redmine redmine/instances/default/internal/reconfiguring boolean false"; \
      echo "redmine redmine/instances/default/pgsql/authmethod-user select password"; \
      echo "# Connection method for MySQL database of redmine/instances/default:"; \
      echo "redmine redmine/instances/default/mysql/method select unix socket"; \
      echo "redmine redmine/instances/default/pgsql/admin-user string postgres"; \
      echo "redmine redmine/instances/default/install-error select abort"; \
      echo "redmine redmine/notify-migration note"; \
      echo "# username for redmine/instances/default:"; \
      echo "redmine redmine/instances/default/db/app-user string redmine_default"; \
      echo "redmine redmine/instances/default/pgsql/authmethod-admin select ident"; \
      echo "# Perform upgrade on database for redmine/instances/default with dbconfig-common?"; \
      echo "redmine redmine/instances/default/dbconfig-upgrade boolean true"; \
      echo "redmine redmine/instances/default/pgsql/manualconf note"; \
      echo "# Host name of the database server for redmine/instances/default:"; \
      echo "redmine redmine/instances/default/remote/host select"; \
      echo "redmine redmine/current-instances string default"; \
      echo "# Configure database for redmine/instances/default with dbconfig-common?"; \
      echo "redmine redmine/instances/default/dbconfig-install boolean false"; \
      echo "# Default redmine language:"; \
      echo "redmine redmine/default-language select ${defaultLocale}"; \
      echo "# storage directory for redmine/instances/default:"; \
      echo "redmine redmine/instances/default/db/basepath string"; \
      echo "# database name for redmine/instances/default:"; \
      echo "redmine redmine/instances/default/db/dbname string redmine_default"; \
      echo "redmine redmine/instances/default/internal/skip-preseed boolean true"; \
      echo "redmine redmine/instances/default/remove-error select abort"; \
      echo "# Deconfigure database for redmine/instances/default with dbconfig-common?"; \
      echo "redmine redmine/instances/default/dbconfig-remove boolean"; \
      echo "redmine redmine/instances/default/upgrade-error select abort"; \
      echo "# Do you want to purge the database for redmine/instances/default?"; \
      echo "redmine redmine/instances/default/purge boolean false"; \
      echo "# Database type to be used by redmine/instances/default:"; \
      echo "redmine redmine/instances/default/database-type select"; ) \
    | debconf-set-selections
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y redmine-mysql
RUN touch /firstrun
ADD start.sh /start.sh
CMD /start.sh
