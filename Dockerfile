FROM crystallang/crystal:0.34.0-alpine

RUN apk add ncurses-static sqlite-dev sqlite-static
