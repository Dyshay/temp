FROM hseeberger/scala-sbt:11.0.12_1.5.5_2.13.6 AS build
WORKDIR /app

COPY project project
COPY build.sbt .
RUN sbt update

COPY . .
RUN sbt clean stage

FROM openjdk:11-jre-slim AS runtime
WORKDIR /app

COPY --from=build /app/target/universal/stage .

ENV PLAY_HTTP_SECRET_KEY=changeme
EXPOSE 9000

CMD ["bin/scala-play-api", "-Dplay.server.http.address=0.0.0.0"]
