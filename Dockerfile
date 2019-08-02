FROM microsoft/aspnetcore-build:2.0 AS build-env

RUN echo 'hello world.  v0.2'
RUN echo 'hello world.  v0.1'

WORKDIR /app
