FROM eclipse-temurin:21-jre-alpine
WORKDIR /app
RUN apk upgrade --no-cache && addgroup -S appgroup && adduser -S appuser -G appgroup
USER appuser
COPY services/circleguard-file-service/build/libs/*.jar app.jar
EXPOSE 8085
ENTRYPOINT ["java", "-jar", "app.jar"]
