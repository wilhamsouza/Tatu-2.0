FROM node:22-alpine AS build

WORKDIR /app

COPY backend/package*.json ./
RUN npm ci

COPY backend/tsconfig.json ./tsconfig.json
COPY backend/prisma ./prisma
COPY backend/src ./src

RUN npx prisma generate
RUN npm run build

FROM node:22-alpine AS runtime

WORKDIR /app

ENV NODE_ENV=production

COPY --from=build /app/node_modules ./node_modules
COPY --from=build /app/dist ./dist
COPY --from=build /app/prisma ./prisma
COPY backend/scripts/docker-entrypoint.sh ./scripts/docker-entrypoint.sh

RUN sed -i 's/\r$//' ./scripts/docker-entrypoint.sh \
    && chmod +x ./scripts/docker-entrypoint.sh \
    && mkdir -p /app/data

EXPOSE 3333

ENTRYPOINT ["./scripts/docker-entrypoint.sh"]
CMD ["node", "dist/index.js"]
