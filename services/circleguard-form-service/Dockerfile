FROM eclipse-temurin:21-jre-alpine
WORKDIR /app
RUN apk upgrade --no-cache && addgroup -S appgroup && adduser -S appuser -G appgroup
USER appuser
COPY services/circleguard-form-service/build/libs/*.jar app.jar
EXPOSE 8086
ENTRYPOINT ["java", "-jar", "app.jar"]
