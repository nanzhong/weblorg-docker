FROM silex/emacs:29.1

RUN apt-get update && apt-get install -y git curl inotify-tools

RUN curl -Ls https://github.com/sass/dart-sass/releases/download/1.32.7/dart-sass-1.32.7-linux-x64.tar.gz | tar -C /usr/local/bin --strip-components 1 -xvzf - dart-sass/sass

RUN curl -Lo /usr/local/bin/caddy 'https://caddyserver.com/api/download?os=linux&arch=amd64' && chmod +x /usr/local/bin/caddy

EXPOSE 80

COPY weblorg.sh /usr/local/bin/weblorg

WORKDIR /workspace

ENTRYPOINT ["weblorg"]
CMD ["dev"]
