FROM node:20-alpine

WORKDIR /app
ENV NODE_ENV=production

COPY package.json ./
COPY src ./src

EXPOSE 8080
CMD ["npm", "start"]
