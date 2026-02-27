FROM ruby:3.3-alpine

# 安装依赖
RUN apk add --no-cache \
    build-base \
    postgresql-dev \
    nodejs \
    npm \
    git \
    tzdata

# 设置工作目录
WORKDIR /app

# 复制 Gemfile
COPY Gemfile Gemfile.lock ./

# 安装 Ruby 依赖
RUN bundle config set --local deployment 'true' && \
    bundle config set --local without 'development test' && \
    bundle install

# 复制 package.json
COPY package.json package-lock.json ./

# 安装 Node 依赖
RUN npm ci --production

# 复制应用代码
COPY . .

# 编译资源
RUN npm run build:css && \
    bundle exec rails assets:precompile

# 暴露端口
EXPOSE 3000

# 健康检查
HEALTHCHECK --interval=30s --timeout=3s --start-period=40s \
  CMD curl -f http://localhost:3000/ || exit 1

# 启动脚本
CMD ["sh", "-c", "bundle exec rails db:migrate && bundle exec puma -C config/puma.rb"]
