FROM redmine
MAINTAINER mwaeckerlin

RUN { \
		echo; \
		echo 'unless ENV["REDMINE_RELATIVE_URL_ROOT"].to_s.empty?'; \
		echo '  Redmine::Utils::relative_url_root = ENV["REDMINE_RELATIVE_URL_ROOT"]'; \
		echo 'end'; \
	} >> config/environment.rb
