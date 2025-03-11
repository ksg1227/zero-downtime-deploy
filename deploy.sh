#!/bin/bash

IS_BLUE_RUNNING=$(docker ps | grep blue)
export NGINX_CONF="./etc/nginx/nginx.conf"

# blue 가 실행 중이면 green 을 up
if [ -z "$IS_BLUE_RUNNING" ]; then
  echo "### BLUE => GREEN ####"

  echo ">>> green 컨테이너 실행"
  docker compose up -d green
  sleep 5

  echo ">>> health check 진행..."
  while true; do
    RESPONSE=$(curl http://localhost:8082/actuator/health | grep UP)
    if [ -n "$RESPONSE" ]; then
      ehco ">>> green health check 성공! "
      break;
    fi
    sleep 3
  done;

  echo ">>> Nginx 설정 변경 (green)"
  sudo sed -i 's/set $ACTIVE_APP blue;/set $ACTIVE_APP green;/' $NGINX_CONF
  sudo nginx -s reload

  echo ">>> blue 컨테이너 종료"
  docker compose stop blue

# blue 가 실행 중이면 green 을 up
else
  echo "### GREEN => BLUE ####"
  echo ">>> blue 컨테이너 실행"
  docker compose up -d blue

  echo ">>> health check 진행..."
  while true; do
    RESPONSE=$(curl http://localhost:8081/actuator/health | grep UP)
    if [ -n "$RESPONSE" ]; then
      ehco ">>> blue health check 성공! "
      break;
    fi
    sleep 3
  done;

  echo ">>> Nginx 설정 변경 (blue)"
  sudo sed -i 's/set $ACTIVE_APP green;/set $ACTIVE_APP blue;/' $NGINX_CONF
  sudo nginx -s reload

  echo ">>> green 컨테이너 종료"
  docker compose stop green
fi


