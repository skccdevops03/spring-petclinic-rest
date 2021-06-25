FROM adoptopenjdk/openjdk11:alpine-jre
ARG JAR_FILE=target/*.jar
COPY ${JAR_FILE} app.jar
ADD scouter.agent.jar scouter.agent.jar
ADD scouter.conf scouter.conf
ENV JAVA_OPTS=""
ENTRYPOINT ["java","-Djava.security.egd=file:/dev/./urandom","-Dscouter.config=/scouter.conf","-javaagent:/scouter.agent.jar","-jar","/app.jar"]
