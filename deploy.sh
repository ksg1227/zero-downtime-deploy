#!/bin/bash

IS_BLUE_RUNNING=$(docker ps | grep blue)
export NGINX_CONF="/etc/nginx/nginx.conf"

# 컨테이너 디버깅 함수
debug_container() {
  local container_name=$1
  echo ">>> 컨테이너 디버깅: $container_name"
  echo ">>> Docker 컨테이너 상태 확인:"
  docker ps -a | grep $container_name

  echo ">>> 컨테이너 로그 확인:"
  docker logs $container_name

  echo ">>> 컨테이너 내부 네트워크 확인:"
  docker exec $container_name netstat -tulpn || echo "네트워크 상태 확인 실패"

  echo ">>> Spring 애플리케이션 프로세스 확인:"
  docker exec $container_name ps -ef | grep java || echo "프로세스 확인 실패"

  echo ">>> 컨테이너 내부에서 직접 헬스 체크:"
  docker exec $container_name curl -v localhost:8080/actuator/health || echo "내부 헬스 체크 실패"
}

# blue 가 실행 중이면 green 을 up
if [ -n "$IS_BLUE_RUNNING" ]; then
  echo "### BLUE => GREEN ####"

  echo ">>> green 컨테이너 실행"
  docker compose up -d green

  echo ">>> 애플리케이션 시작 대기 중... (15초)"
  sleep 15

  # 컨테이너 디버깅
  debug_container "green"

  echo ">>> 외부에서 green 헬스 체크 시도:"
  curl -v http://localhost:8082/actuator/health

  echo ">>> 계속 배포를 진행하시겠습니까? (y/n)"
  read answer
  if [ "$answer" != "y" ]; then
    echo ">>> 배포 중단"
    exit 1
  fi

  echo ">>> Nginx 설정 변경 (green)"
  sudo sed -i 's/set $ACTIVE_APP blue;/set $ACTIVE_APP green;/' $NGINX_CONF
  sudo nginx -s reload

  echo ">>> blue 컨테이너 종료"
  docker compose stop blue

# green 이 실행 중이면 blue 를 up
else
  echo "### GREEN => BLUE ####"

  echo ">>> blue 컨테이너 실행"
  docker compose up -d blue

  echo ">>> 애플리케이션 시작 대기 중... (15초)"
  sleep 15

  # 컨테이너 디버깅
  debug_container "blue"

  echo ">>> 외부에서 blue 헬스 체크 시도:"
  curl -v http://localhost:8081/actuator/health

  echo ">>> 계속 배포를 진행하시겠습니까? (y/n)"
  read answer
  if [ "$answer" != "y" ]; then
    echo ">>> 배포 중단"
    exit 1
  fi

  echo ">>> Nginx 설정 변경 (blue)"
  sudo sed -i 's/set $ACTIVE_APP green;/set $ACTIVE_APP blue;/' $NGINX_CONF
  sudo nginx -s reload

  echo ">>> green 컨테이너 종료"
  docker compose stop green
fi