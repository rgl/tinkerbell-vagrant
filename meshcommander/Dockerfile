FROM node:14-alpine3.14
RUN npm install meshcommander@0.9.1-a
EXPOSE 4000
# TODO use tini or s6 init to start meshcommander.
CMD ["/node_modules/.bin/meshcommander", "--any", "--port", "4000"]
