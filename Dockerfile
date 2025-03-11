FROM amazoncorretto:17

# 컨테이너 내부에서 80번 포트를 사용하도록 설정
EXPOSE 8080

COPY ./build/libs/*.jar ./app.jar
ENTRYPOINT ["java", "-jar", "app.jar", "--server.port=8080"]
