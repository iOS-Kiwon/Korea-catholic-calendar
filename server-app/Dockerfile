FROM node:20-alpine

WORKDIR /app
ENV NODE_ENV=production

COPY server-app/package.json ./
RUN npm install --omit=dev

COPY server-app/src ./src
COPY assets/calendar ./assets/calendar

EXPOSE 8080
CMD ["npm", "start"]
