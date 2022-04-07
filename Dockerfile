FROM cytopia/phpcs:3

RUN apk add --no-cache bash

COPY entrypoint.sh \
     problem-matcher.json \
     /action/

ENTRYPOINT ["/bin/bash", "/action/entrypoint.sh"]
