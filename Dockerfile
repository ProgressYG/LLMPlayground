FROM ruby:3.2

RUN apt-get update && apt-get install -y \
    python3 \
    python3-pip \
    python3-venv \
    nodejs \
    npm \
    dos2unix \
    && rm -rf /var/lib/apt/lists/*

RUN ln -s /usr/bin/python3 /usr/bin/python

WORKDIR /app

COPY Gemfile Gemfile.lock ./
RUN bundle install

COPY requirements.txt ./
# --break-system-packages 플래그 추가
RUN pip install --break-system-packages --no-cache-dir -r requirements.txt

COPY . .

# Line ending 수정 및 실행 권한 부여
RUN dos2unix start_servers.sh && chmod +x start_servers.sh

EXPOSE 3000 8000

CMD ["./start_servers.sh"]
