FROM cytopia/phpcs:3

RUN apk add --no-cache bash git

COPY entrypoint.sh \
     problem-matcher.json \
     /action/

ENTRYPOINT ["/bin/bash", "/action/entrypoint.sh"]
