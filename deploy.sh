#!/bin/bash

IS_BLUE_RUNNING=$(docker ps | grep blue)
export NGINX_CONF="/etc/nginx/nginx.conf"

# 현재 실행 중인 컨테이너 및 포트 정보 출력
echo ">>> 현재 실행 중인 컨테이너:"
docker ps --format "table {{.ID}}\t{{.Names}}\t{{.Ports}}"

# blue 가 실행 중이면 green 을 up
if [ -n "$IS_BLUE_RUNNING" ]; then
  echo "### BLUE => GREEN ####"

  echo ">>> green 컨테이너 실행"
  docker compose up -d green
  sleep 7

  echo ">>> green 컨테이너의 포트 매핑 확인"
  docker ps --filter "name=green" --format "table {{.Names}}\t{{.Ports}}"

  echo ">>> health check 진행 (http://localhost:8082/actuator/health)..."
  while true; do
    RESPONSE=$(curl -v http://localhost:8082/actuator/health 2>&1)
    echo "$RESPONSE"

    if echo "$RESPONSE" | grep -q "UP"; then
      echo ">>> green health check 성공!"
      break
    fi
    sleep 3
  done

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
  sleep 7

  echo ">>> blue 컨테이너의 포트 매핑 확인"
  docker ps --filter "name=blue" --format "table {{.Names}}\t{{.Ports}}"

  echo ">>> health check 진행 (http://localhost:8081/actuator/health)..."
  while true; do
    RESPONSE=$(curl -v http://localhost:8081/actuator/health 2>&1)
    echo "$RESPONSE"

    if echo "$RESPONSE" | grep -q "UP"; then
      echo ">>> blue health check 성공!"
      break
    fi
    sleep 3
  done

  echo ">>> Nginx 설정 변경 (blue)"
  sudo sed -i 's/set $ACTIVE_APP green;/set $ACTIVE_APP blue;/' $NGINX_CONF
  sudo nginx -s reload

  echo ">>> green 컨테이너 종료"
  docker compose stop green
fi
