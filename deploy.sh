#!/bin/bash

IS_BLUE_RUNNING=$(docker ps | grep blue)
export NGINX_CONF="/etc/nginx/nginx.conf"

# blue 가 실행 중이면 green 을 up
if [ -n "$IS_BLUE_RUNNING" ]; then
  echo "### BLUE => GREEN ####"

  echo ">>> green 컨테이너 실행"
  docker compose up -d green

  echo ">>> 애플리케이션 시작 대기 중... (20초)"
  sleep 20

  echo ">>> health check 진행..."
  MAX_RETRIES=5
  RETRY_COUNT=0

  while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    echo ">>> health check 시도 중... ($((RETRY_COUNT+1))/$MAX_RETRIES)"
    RESPONSE=$(curl -s -m 5 http://localhost:8082/actuator/health || echo "FAILED")

    if [[ "$RESPONSE" == *"UP"* ]]; then
      echo ">>> green health check 성공!"
      break
    else
      echo ">>> health check 실패, 재시도 중..."
      RETRY_COUNT=$((RETRY_COUNT+1))

      if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
        echo ">>> 최대 재시도 횟수에 도달했습니다. 배포를 중단합니다."
        docker compose logs green
        docker compose stop green
        exit 1
      fi

      sleep 5
    fi
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

  echo ">>> 애플리케이션 시작 대기 중... (20초)"
  sleep 20

  echo ">>> health check 진행..."
  MAX_RETRIES=5
  RETRY_COUNT=0

  while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    echo ">>> health check 시도 중... ($((RETRY_COUNT+1))/$MAX_RETRIES)"
    RESPONSE=$(curl -s -m 5 http://localhost:8081/actuator/health || echo "FAILED")

    if [[ "$RESPONSE" == *"UP"* ]]; then
      echo ">>> blue health check 성공!"
      break
    else
      echo ">>> health check 실패, 재시도 중..."
      RETRY_COUNT=$((RETRY_COUNT+1))

      if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
        echo ">>> 최대 재시도 횟수에 도달했습니다. 배포를 중단합니다."
        docker compose logs blue
        docker compose stop blue
        exit 1
      fi

      sleep 5
    fi
  done

  echo ">>> Nginx 설정 변경 (blue)"
  sudo sed -i 's/set $ACTIVE_APP green;/set $ACTIVE_APP blue;/' $NGINX_CONF
  sudo nginx -s reload

  echo ">>> green 컨테이너 종료"
  docker compose stop green
fi