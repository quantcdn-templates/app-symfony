# Symfony Application Template

A production-ready Symfony application template for Quant Cloud, featuring PHP 8.4, Apache with mod_php, and Docker containerization.

[![Deploy to Quant Cloud](https://www.quantcdn.io/img/quant-deploy-btn-sml.svg)](https://dashboard.quantcdn.io/cloud-apps/create/starter-kit/app-symfony)

## Features

- **Symfony 7.1** - Latest version of the Symfony framework
- **PHP 8.4** with common extensions (GD, PDO, BCMath, Intl, etc.)
- **Apache + mod_php** - Simple single-container setup
- **Doctrine ORM** - Ready for database integration
- **Twig Templates** - Powerful templating engine
- **Composer** for dependency management
- **Docker & Docker Compose** for containerization
- **Persistent storage** for Symfony's var directory
- **Quant integration** ready out of the box:
  - Client IP handling via `Quant-Client-IP` header
  - Host header override for `Quant-Orig-Host`
  - SMTP relay support for email delivery
  - UID/GID 1000 mapping for EFS compatibility
- **Logging to stdout/stderr** for Docker best practices

## Quick Start

### Prerequisites

- Docker and Docker Compose
- Git

### Local Development

1. Clone this template:
   ```bash
   git clone <your-repo-url> my-symfony-app
   cd my-symfony-app
   ```

2. Copy and configure environment variables:
   ```bash
   cp docker-compose.override.yml.example docker-compose.override.yml
   ```

   Edit `docker-compose.override.yml` to set your local environment variables, especially:
   - `APP_SECRET` - Generate a random secret key
   - Database credentials (if using Doctrine)

3. Start the application:
   ```bash
   docker-compose up -d
   ```

4. Access your application at `http://localhost`

## Configuration

### Environment Variables

Key environment variables you should configure:

#### Symfony Configuration
- `APP_SECRET` - Application secret key (required)
- `APP_ENV` - Application environment (default: prod)
- `APP_DEBUG` - Enable debug mode (default: 0)

#### Database Configuration (optional)
- `DATABASE_URL` - Full database connection URL
- `DB_HOST` - Database host (default: db)
- `DB_DATABASE` - Database name (default: symfony)
- `DB_USERNAME` - Database username (default: symfony)
- `DB_PASSWORD` - Database password (default: symfony)

#### SMTP Configuration
- `QUANT_SMTP_RELAY_ENABLED` - Enable Postfix SMTP relay (default: false)
- `QUANT_SMTP_HOST` - SMTP server hostname
- `QUANT_SMTP_PORT` - SMTP server port (default: 587)
- `QUANT_SMTP_USERNAME` - SMTP authentication username
- `QUANT_SMTP_PASSWORD` - SMTP authentication password
- `QUANT_SMTP_FROM` - From email address
- `QUANT_SMTP_FROM_NAME` - From display name

#### Quant Integration
- `QUANT_ENABLED` - Enable Quant integration
- `QUANT_API_ENDPOINT` - Quant API endpoint
- `QUANT_CUSTOMER` - Your Quant customer ID
- `QUANT_PROJECT` - Your Quant project ID
- `QUANT_TOKEN` - Your Quant API token

### File Storage

The application uses a persistent Docker volume for the Symfony `var` directory to ensure cache files and logs persist across container restarts.

## Development

### Console Commands

Run Symfony console commands using Docker Compose:

```bash
# Clear cache
docker-compose exec symfony php bin/console cache:clear

# List all routes
docker-compose exec symfony php bin/console debug:router

# Create a controller
docker-compose exec symfony php bin/console make:controller

# Run migrations (if using Doctrine)
docker-compose exec symfony php bin/console doctrine:migrations:migrate
```

### Composer

Install new packages:

```bash
docker-compose exec symfony composer require package-name
```

### Database Access (if configured)

Access the MySQL database directly:

```bash
docker-compose exec db mysql -u symfony -p symfony
```

### Logs

View application logs:

```bash
docker-compose logs -f symfony
```

## Deployment

This template is designed to work seamlessly with Quant's deployment platform. The Docker container includes all necessary configurations for production deployment.

### Key Production Features

1. **Optimized Dockerfile**: Multi-stage build with proper layer caching
2. **Security**: Runs as www-data user, secure permissions
3. **Performance**: OPcache enabled, Composer autoloader optimization
4. **Logging**: Configured for container-based logging to stderr
5. **Health Checks**: Built-in health check endpoints

## Directory Structure

```
app-symfony/
├── src/                    # Symfony application files
│   ├── bin/               # Console scripts
│   ├── config/            # Configuration files
│   ├── public/            # Web root (DocumentRoot)
│   ├── src/               # Application source code
│   │   ├── Controller/    # Controllers
│   │   └── Kernel.php     # Application kernel
│   ├── templates/         # Twig templates
│   ├── translations/      # Translation files
│   └── var/               # Cache and logs (persistent volume)
├── quant/                 # Quant integration files
│   ├── entrypoints/       # Startup scripts
│   ├── php.ini.d/         # PHP configuration
│   ├── entrypoints.sh     # Main entrypoint script
│   └── meta.json          # Template metadata
├── .github/workflows/     # CI/CD workflows
├── Dockerfile             # Container definition
├── docker-compose.yml     # Service orchestration
└── README.md              # This file
```

## Troubleshooting

### Cache Issues

If you encounter cache-related errors:

```bash
docker-compose exec symfony php bin/console cache:clear
docker-compose exec symfony php bin/console cache:warmup
```

### Permission Issues

If you encounter file permission issues:

```bash
docker-compose exec symfony chown -R www-data:www-data /var/www/html/var
docker-compose exec symfony chmod -R 775 /var/www/html/var
```

### Database Connection Issues (if using Doctrine)

1. Ensure the database container is running:
   ```bash
   docker-compose ps
   ```

2. Check database logs:
   ```bash
   docker-compose logs db
   ```

3. Verify database credentials in your environment configuration.

## Adding Database Support

This template comes without a database by default. To add MySQL support:

1. Uncomment the database service in `docker-compose.override.yml`
2. Update the `DATABASE_URL` environment variable
3. Create your entities and run migrations:
   ```bash
   docker-compose exec symfony php bin/console make:entity
   docker-compose exec symfony php bin/console make:migration
   docker-compose exec symfony php bin/console doctrine:migrations:migrate
   ```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test with Docker Compose
5. Submit a pull request

## License

This Symfony application template is open-sourced software licensed under the [MIT license](https://opensource.org/licenses/MIT).
