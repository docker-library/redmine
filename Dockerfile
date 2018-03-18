FROM redmine
MAINTAINER mwaeckerlin

RUN sed -i '/Rails.application.initialize/d' config/environment.rb
RUN { \
		echo; \
		echo 'unless ENV["REDMINE_RELATIVE_URL_ROOT"].to_s.empty?'; \
		echo '  Redmine::Utils::relative_url_root = ENV["REDMINE_RELATIVE_URL_ROOT"]'; \
		echo 'end'; \
                echo; \
                echo 'Rails.application.initialize!'; \
	} >> config/environment.rb
