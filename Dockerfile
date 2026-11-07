# Étape 1 : Build avec Maven
FROM maven:3.9-eclipse-temurin-17 AS build
WORKDIR /app
COPY pom.xml .
COPY src ./src
RUN mvn -DskipTests clean package

# Étape 2 : Image finale légère
FROM eclipse-temurin:17-jre
WORKDIR /app
# curl is used by the Compose health check for the application endpoint.
RUN apt-get update && apt-get install -y --no-install-recommends curl \
    && rm -rf /var/lib/apt/lists/*
# On récupère le fichier JAR généré à l'étape précédente
COPY --from=build /app/target/timesheet-devops-1.0.jar app.jar
EXPOSE 8082
ENTRYPOINT ["java","-jar","app.jar"]
