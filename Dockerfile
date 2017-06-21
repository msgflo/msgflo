FROM node:6

# Export the Websocket port for Flowhub connection
EXPOSE 3569

# Reduce npm install verbosity, overflows Travis CI log view
ENV NPM_CONFIG_LOGLEVEL warn

RUN mkdir -p /var/app
WORKDIR /var/app

# Install MsgFlo and dependencies
COPY . /var/app
RUN npm install

# Install msgflo-python
RUN apt-get update && apt-get install -y \
  python \
  python-dev \
  python-pip
RUN pip install msgflo

# Map the volumes
VOLUME /var/app/graphs /var/app/participants /var/app/tests

CMD npm start
