# 前端 Dockerfile - 多阶段构建
FROM node:22-alpine AS build

WORKDIR /app

# 安装依赖
COPY package.json package-lock.json* ./
RUN npm install

# 复制源代码
COPY . .

# 构建参数
ARG VITE_API_BASE_URL=/api
ENV VITE_API_BASE_URL=$VITE_API_BASE_URL

# 构建
RUN npm run build

# 生产环境使用 Nginx
FROM nginx:alpine

# 复制构建产物
COPY --from=build /app/dist /usr/share/nginx/html

# 复制 Nginx 配置
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
