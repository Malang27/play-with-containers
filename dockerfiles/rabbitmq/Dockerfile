FROM rabbitmq:3.12-alpine

# Installer le plugin management
RUN rabbitmq-plugins enable --offline rabbitmq_management

# Variables d'environnement par défaut
ENV RABBITMQ_DEFAULT_USER=rabbitmq_user
ENV RABBITMQ_DEFAULT_PASS=rabbitmq_pass

# Exposer les ports RabbitMQ
EXPOSE 5672 15672

# Health check
HEALTHCHECK --interval=30s --timeout=30s --start-period=60s --retries=3 \
    CMD rabbitmq-diagnostics -q ping || exit 1

# Utiliser l'entrypoint par défaut de rabbitmq
ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["rabbitmq-server"]