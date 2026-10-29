<?php

namespace App\Doctrine;

use Doctrine\DBAL\Driver;
use Doctrine\DBAL\Driver\Connection;
use Doctrine\DBAL\Driver\Middleware;
use Doctrine\DBAL\Driver\Middleware\AbstractDriverMiddleware;
use PDO;

/** Apply the same managed-database trust policy as the Drupal template. */
final class ManagedDatabaseTls implements Middleware
{
    public function wrap(Driver $driver): Driver
    {
        return new class($driver) extends AbstractDriverMiddleware {
            public function connect(array $params): Connection
            {
                if (getenv('DISABLE_DB_TLS') !== 'true') {
                    $ca = '/opt/rds-ca-certs/rds-ca-cert-bundle.pem';
                    if (($params['driver'] ?? '') === 'pdo_mysql') {
                        $params['driverOptions'][PDO::MYSQL_ATTR_SSL_CA] ??= getenv('MYSQL_ATTR_SSL_CA') ?: $ca;
                        $params['driverOptions'][PDO::MYSQL_ATTR_SSL_VERIFY_SERVER_CERT] = true;
                    } elseif (in_array($params['driver'] ?? '', ['pdo_pgsql', 'pgsql'], true)) {
                        $params['sslmode'] = 'verify-full';
                        $params['sslrootcert'] ??= getenv('DB_SSLROOTCERT') ?: $ca;
                    }
                }

                return parent::connect($params);
            }
        };
    }
}
