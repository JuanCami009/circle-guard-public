FROM eclipse-temurin:21-jre-alpine
WORKDIR /app
RUN apk upgrade --no-cache && addgroup -S -g 1001 appgroup && adduser -S -u 1001 -G appgroup appuser
USER 1001
COPY services/circleguard-promotion-service/build/libs/*.jar app.jar
EXPOSE 8088
ENTRYPOINT ["java", "-jar", "app.jar"]
