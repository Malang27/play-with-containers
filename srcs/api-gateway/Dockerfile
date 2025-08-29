FROM node:18-alpine

WORKDIR /app

# Installer wget pour les health checks
RUN apk add --no-cache wget

# Copier package.json et package-lock.json (si disponible)
COPY package*.json ./

# Installer les dépendances
RUN npm ci --only=production && npm cache clean --force

# Copier le code source
COPY . .

# Créer le répertoire pour les logs avec les bonnes permissions
RUN mkdir -p /app/logs && chown -R node:node /app/logs

# Créer un utilisateur non-root pour la sécurité
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001

# Changer les permissions du répertoire de travail
RUN chown -R nodejs:nodejs /app

# Changer vers l'utilisateur non-root
USER nodejs

# Exposer le port de l'application
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:3000/health || exit 1

# Commande pour démarrer l'application
CMD ["node", "server.js"]